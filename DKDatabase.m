//
//  DKDatabase.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKDatabase.h"
#import "DKDatabasePrivate.h"

#import "DKDatabaseLayout.h"
#import "DKTableDescription.h"

#import "DKFetchRequest.h"

#import "DKDatabaseObjectPrivate.h"
#import "DKDatabaseObject.h"

#import "DKTransaction.h"
#import "DKTransactionPrivate.h"

#import "NSString+Database.h"

#pragma mark -

NSString *const kDKDatabaseConfigurationTableName = @"DKDatabaseConfiguration";

@interface DKDatabase () //Continuation

- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error;

@end

#pragma mark -

@implementation DKDatabase

@synthesize sqliteHandle = mSQLiteHandle;
@synthesize databaseLayout = mDatabaseLayout;

#pragma mark -
#pragma mark Destruction

- (void)cleanUp
{
	if(mTransactionQueue)
	{
		//Cancel all transaction operations.
		[mTransactionQueue cancelAllOperations];
		
		//Wait until any active transactions finish.
		[mTransactionQueue waitUntilAllOperationsAreFinished];
	}
	
	if(mSQLiteHandle)
	{
		//Finalize any active statements.
		sqlite3_stmt *activeStatement;
		while ((activeStatement = sqlite3_next_stmt(mSQLiteHandle, 0)))
		{
			sqlite3_finalize(activeStatement);
		}
		
		//Close the database, and we're done.
		sqlite3_close(mSQLiteHandle);
		mSQLiteHandle = NULL;
	}
}

- (void)dealloc
{
	[self cleanUp];
	
	[mDatabaseLayout release];
	mDatabaseLayout = nil;
	
	[mTransactionQueue release];
	mTransactionQueue = nil;
	
	[super dealloc];
}

- (void)finalize
{
	[self cleanUp];
	[super finalize];
}

#pragma mark -
#pragma mark Construction

- (id)init
{
	NSAssert(NO, @"Attempting to initialize a DKDatabase with `init`. Use initWithDatabaseAtURL:layout:error: instead.");
	return nil;
}

- (id)initWithDatabaseAtURL:(NSURL *)location layout:(id < DKDatabaseLayout >)layout error:(NSError **)error
{
	NSParameterAssert(layout);
	
	if((self = [super init]))
	{
		int status = SQLITE_OK;
		if(location)
			status = sqlite3_open([[location path] UTF8String], &mSQLiteHandle);
		else
			//If we're given a nil location we create the database in memory.
			status = sqlite3_open(":memory:", &mSQLiteHandle);
		
		if(status != SQLITE_OK)
		{
			[self release];
			
			if(error) *error = DKLocalizedError(DKGeneralErrorDomain, 
												status, 
												nil, 
												@"Failed to open database", location, status);
			
			return nil;
		}
		
		if(![self ensureDatabaseIsUsingLayout:layout error:error])
		{
			[self release];
			
			return nil;
		}
		
		mDatabaseLayout = [layout retain];
		
		mTransactionQueue = [NSOperationQueue new];
		[mTransactionQueue setName:@"com.roundabout.databasekit.transaction-queue"];
		[mTransactionQueue setMaxConcurrentOperationCount:1];
		
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Database Interaction

- (BOOL)tableExistsWithName:(NSString *)name
{
	NSString *query = [NSString stringWithFormat:@"PRAGMA table_info(%@)", [name stringByEscapingStringForDatabaseQuery]];
	
	sqlite3_stmt *compiledSQLStatement = NULL;
	if(sqlite3_prepare_v2(mSQLiteHandle, [query UTF8String], -1, &compiledSQLStatement, NULL) == SQLITE_OK)
	{
		BOOL success = (sqlite3_step(compiledSQLStatement) == SQLITE_ROW);
		sqlite3_finalize(compiledSQLStatement);
		
		return success;
	}
	
	return NO;
}

#pragma mark -

- (double)databaseVersion
{
	double version = 0.0;
	if([self tableExistsWithName:kDKDatabaseConfigurationTableName])
	{
		NSString *query = [NSString stringWithFormat:@"SELECT databaseVersion FROM %@", kDKDatabaseConfigurationTableName];
		
		sqlite3_stmt *compiledSQLStatement = NULL;
		if(sqlite3_prepare_v2(mSQLiteHandle, [query UTF8String], -1, &compiledSQLStatement, NULL) == SQLITE_OK)
		{
			//Step to the first and only row.
			int status = sqlite3_step(compiledSQLStatement);
			if(status == SQLITE_ROW)
				version = sqlite3_column_double(compiledSQLStatement, 0);
			else
				NSLog(@"*** DatabaseKit: Could not look up version for database. Error %d %s.", status, sqlite3_errmsg(mSQLiteHandle));
			
			sqlite3_finalize(compiledSQLStatement);
		}
	}
	
	return version;
}

#pragma mark -

- (NSSet *)objectsInTable:(DKTableDescription *)table matchingQuery:(NSString *)query error:(NSError **)error
{
	NSParameterAssert(table);
	
	__block NSError *temporaryError = nil;
	__block NSMutableSet *objects = nil;
	[self transaction:^(DKTransaction *transaction) {
		
		NSString *query = nil;
		if(query)
			query = [NSString stringWithFormat:@"SELECT _dk_uniqueIdentifier FROM %@ WHERE %@", table.name, query];
		else
			query = [NSString stringWithFormat:@"SELECT _dk_uniqueIdentifier FROM %@", table.name];
		
		if(![transaction compileSQLStatement:query error:error])
			return;
		
		objects = [NSMutableSet set];
		while ([transaction evaluateStatement] == SQLITE_ROW)
		{
			int64_t uniqueIdentifier = [transaction longLongForColumnAtIndex:0];
			id databaseObject = [[[table databaseObjectClass] alloc] initWithUniqueIdentifier:uniqueIdentifier table:table database:self];
			if(databaseObject)
				[objects addObject:databaseObject];
		}
	}];
	
	if(temporaryError)
		if(error) *error = temporaryError;
	
	return objects;
}

- (NSArray *)executeFetchRequest:(DKFetchRequest *)fetchRequest error:(NSError **)error
{
	NSParameterAssert(fetchRequest);
	
	NSSet *objects = [self objectsInTable:fetchRequest.table matchingQuery:fetchRequest.filterString error:error];
	if(objects)
	{
		NSArray *sortDescriptors = fetchRequest.sortDescriptors;
		if(sortDescriptors)
			return [objects sortedArrayUsingDescriptors:sortDescriptors];
		
		return [objects allObjects];
	}
	return nil;
}

- (void)transaction:(void(^)(DKTransaction *transaction))handler
{
	//All transactions are executed serially on a background thread.
	[mTransactionQueue addOperationWithBlock:^{
		DKTransaction *transaction = [[DKTransaction alloc] initWithDatabase:self];
		@try
		{
			handler(transaction);
		}
		@finally
		{
			[transaction release];
		}
	}];
}

#pragma mark -
#pragma mark Database set up

- (BOOL)_createTableWithDescription:(DKTableDescription *)tableDescription transaction:(DKTransaction *)transaction error:(NSError **)error
{
	NSString *entityName = [tableDescription.name stringByEscapingStringForDatabaseQuery];
	
	//
	//	Create the base query. All tables created by DatabaseKit have
	//	a uuid column. This can be used to safely identify values in the
	//	database across application launches.
	//
	NSMutableString *query = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (_dk_uniqueIdentifier BIGINT PRIMARY KEY NOT NULL", entityName];
	
	
	for (id property in tableDescription.properties)
	{
		if([property isKindOfClass:[DKAttributeDescription class]])
		{
			DKAttributeDescription *attribute = (DKAttributeDescription *)property;
			DKAttributeType attributeType = attribute.type;
			
			//
			//	Look up the SQLite type for the high level type we're passed in
			//	and append the base of this type.
			//
			[query appendFormat:@", %@ %@", attribute.name, DKAttributeTypeToSQLiteType(attributeType)];
			
			
			//
			//	If an attribute is required, we append the NOT NULL column constraint.
			//
			if(attribute.isRequired)
				[query appendString:@" NOT NULL"];
			
			
			//
			//	Currently default value is only supported for string/float/integer/int*
			//	columns. Attempting to give a default value to anything else will do nothing.
			//
			NSString *defaultValue = attribute.defaultValue;
			if(defaultValue)
			{
				if(attributeType == DKAttributeTypeString)
				{
					[query appendFormat:@" DEFAULT('%@')", [defaultValue stringByEscapingStringForDatabaseQuery]];
				}
				else if(attributeType == DKAttributeTypeFloat)
				{
					[query appendFormat:@" DEFAULT(%f)", [defaultValue doubleValue]];
				}
				else if((attributeType >= DKAttributeTypeInteger) && (attributeType <= DKAttributeTypeInt64))
				{
					[query appendFormat:@" DEFAULT(%lld)", [defaultValue longLongValue]];
				}
				else
				{
					NSLog(@"*** DatabaseKit: Type %d does not support default values.", attributeType);
				}
			}
		}
		else if([property isKindOfClass:[DKRelationshipDescription class]])
		{
			NSLog(@"*** DatabaseKit: Relationships are not implemented.");
		}
		else
		{
			NSAssert(NO, @"Unexpected object of type %@ passed in with table properties.", [property class]);
		}
	}
	
	
	//
	//	Here, we close the query.
	//
	[query appendString:@");"];
	
	return [transaction executeSQLStatement:query error:error];
}

- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error
{
	DKTransaction *transaction = [[[DKTransaction alloc] initWithDatabase:self] autorelease];
	
	if(![self tableExistsWithName:kDKDatabaseConfigurationTableName])
	{
		NSString *query = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (databaseVersion FLOAT NOT NULL, databaseKitVersion FLOAT NOT NULL);", kDKDatabaseConfigurationTableName, [layout databaseVersion]];
		if(![transaction executeSQLStatement:query error:error])
			return NO;
		
		query = [NSString stringWithFormat:@"INSERT INTO %@ (databaseVersion, databaseKitVersion) VALUES(%f, 1.0);", kDKDatabaseConfigurationTableName, [layout databaseVersion]];
		if(![transaction executeSQLStatement:query error:error])
			return NO;
		
		query = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS TableSequence (name TEXT NOT NULL, offset BIGINT DEFAULT(0));"];
		if(![transaction executeSQLStatement:query error:error])
			return NO;
	}
	
	for (DKTableDescription *table in [layout tables])
	{
		NSString *tableName = [table.name stringByEscapingStringForDatabaseQuery];
		if(![self tableExistsWithName:tableName])
		{
			if(![self _createTableWithDescription:table transaction:transaction error:error])
				return NO;
			
			NSString *statement = [NSString stringWithFormat:@"INSERT OR IGNORE INTO TableSequence (name, offset) VALUES ('%@', 0)", tableName];
			if(![transaction executeSQLStatement:statement error:error])
				return NO;
		}
	}
	
	return YES;
}

@end
