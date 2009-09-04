//
//  DKDatabase.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKDatabase.h"
#import "DKDatabaseLayout.h"

BOOL DKTypeStringIsValidHighLevelType(NSString *type)
{
	NSCParameterAssert(type);
	
	return ([type isEqualToString:@"string"] || 
			[type isEqualToString:@"date"] || 
			[type isEqualToString:@"integer"] || 
			[type isEqualToString:@"int8"] || 
			[type isEqualToString:@"int16"] || 
			[type isEqualToString:@"int32"] || 
			[type isEqualToString:@"int64"] || 
			[type isEqualToString:@"float"] || 
			[type isEqualToString:@"data"] || 
			[type isEqualToString:@"transformable"] ||
			(NSClassFromString(type) != nil));
}

NSString *DKTypeStringConvertToSQLType(NSString *type)
{
	NSCParameterAssert(type);
	
	if([type isEqualToString:@"string"])
		return @"TEXT";
	else if([type isEqualToString:@"date"])
		return @"DATETIME";
	else if([type isEqualToString:@"int8"])
		return @"TINYINT";
	else if([type isEqualToString:@"int16"])
		return @"SMALLINT";
	else if([type isEqualToString:@"int32"])
		return @"INT";
	else if([type isEqualToString:@"int64"])
		return @"BIGINT";
	else if([type isEqualToString:@"float"])
		return @"FLOAT";
	else if([type isEqualToString:@"data"] || [type isEqualToString:@"transformable"] || (NSClassFromString(type) != nil))
		return @"BLOB";
	
	//
	//	The high level integer type behaves like NSInteger. On 32-bit systems
	//	its an INT value in the database, and on 64-bit systems its a BIGINT value.
	//
	if([type isEqualToString:@"integer"])
#if __LP64__
		return @"BIGINT";
#else
		return @"INT";
#endif /* __LP64__ */
	
	return nil;
}

#pragma mark -

NSString *const kPKDatabaseConfigurationTableName = @"PKDatabaseConfiguration";

@interface DKDatabase () //Continuation

- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error;

@end

#pragma mark -

@implementation DKDatabase

@synthesize sqliteHandle = mSQLiteHandle;
@dynamic databaseVersion;

#pragma mark -
#pragma mark Destruction

- (void)cleanUp
{
	if(mSQLiteHandle)
	{
		//TODO: Handle pending transactions.
		
		sqlite3_close(mSQLiteHandle);
		mSQLiteHandle = NULL;
	}
}

- (void)dealloc
{
	[self cleanUp];
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
	NSParameterAssert(location);
	NSAssert([location isFileURL], @"Expected file URL, none file URL %@ given.", location);
	
	if((self = [super init]))
	{
		int status = sqlite3_open([[location path] UTF8String], &mSQLiteHandle);
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
		
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Database Interaction

- (BOOL)tableExistsInDatabaseByName:(NSString *)name
{
	NSString *query = [NSString stringWithFormat:@"PRAGMA table_info(%@)", name];
	
	sqlite3_stmt *compiledSQLStatement = NULL;
	if(sqlite3_prepare_v2(mSQLiteHandle, [query UTF8String], -1, &compiledSQLStatement, NULL) == SQLITE_OK)
	{
		BOOL success = (sqlite3_step(compiledSQLStatement) == SQLITE_ROW);
		sqlite3_finalize(compiledSQLStatement);
		
		return success;
	}
	
	return NO;
}

- (BOOL)executeUpdateSQL:(NSString *)query error:(NSError **)error
{
	NSLog(@"Running update query %@", query);
	
	char *errorMessage = NULL;
	int status = SQLITE_OK;
	if((status = sqlite3_exec(mSQLiteHandle, [query UTF8String], NULL, NULL, &errorMessage)) != SQLITE_OK)
	{
		NSLog(@"Query %@ failed with error %d %s.", query, status, errorMessage);
		
		if(error) *error = DKLocalizedError(DKGeneralErrorDomain, 
											status, 
											nil, 
											@"Update query failed", query, status, errorMessage);
		
		sqlite3_free(errorMessage);
		
		return NO;
	}
	
	return YES;
}

#pragma mark -

- (double)databaseVersion
{
	double version = 0.0;
	if([self tableExistsInDatabaseByName:kPKDatabaseConfigurationTableName])
	{
		NSString *query = [NSString stringWithFormat:@"SELECT databaseVersion FROM %@", kPKDatabaseConfigurationTableName];
		
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
#pragma mark Set up

- (BOOL)_createTableWithEntityLayoutDescription:(NSDictionary *)entityLayout error:(NSError **)error
{
	NSString *entityName = [entityLayout objectForKey:kDKEntityNameKey];
	
	//
	//	Create the base query. All tables created by DatabaseKit have
	//	a uuid column. This can be used to safely identify values in the
	//	database across application launches.
	//
	NSMutableString *query = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (uuid TEXT NOT NULL", entityName];
	
	
	for (NSDictionary *attribute in [entityLayout valueForKey:kDKEntityAttributesKey])
	{
		NSString *name = [attribute valueForKey:kDKAttributeNameKey];
		NSString *type = [attribute valueForKey:kDKAttributeTypeKey];
		
		if(DKTypeStringIsValidHighLevelType(type))
		{
			//
			//	Look up the SQLite type for the high level type we're passed in
			//	and append the base of this type.
			//
			[query appendFormat:@", %@ %@", name, DKTypeStringConvertToSQLType(type)];
			
			
			//
			//	If an attribute is required, we append the NOT NULL column constraint.
			//
			if([[attribute valueForKey:kDKAttributeRequiredKey] boolValue])
				[query appendString:@" NOT NULL"];
			
			
			//
			//	Currently default value is only supported for string/float/integer/int*
			//	columns. Attempting to give a default value to anything else will do nothing.
			//
			NSString *defaultValue = [attribute valueForKey:kDKAttributeDefaultValueKey];
			if(defaultValue)
			{
				if([type isEqualToString:@"string"])
				{
					[query appendFormat:@" DEFAULT('%@')", [defaultValue stringByReplacingOccurrencesOfString:@"'" 
																								   withString:@"''"]];
				}
				else if([type isEqualToString:@"float"])
				{
					[query appendFormat:@" DEFAULT(%f)", [type doubleValue]];
				}
				else if([type isEqualToString:@"integer"] || [type isEqualToString:@"int8"] || 
						[type isEqualToString:@"int16"] || [type isEqualToString:@"int32"] || 
						[type isEqualToString:@"int64"])
				{
					[query appendFormat:@" DEFAULT(%lld)", [type longLongValue]];
				}
				else
				{
					NSLog(@"*** DatabaseKit: Type %@ does not support default values.", type);
				}
			}
		}
		else
		{
			NSLog(@"*** DatabaseKit: Unsupported type %@ by name %@ given.", type, name);
		}
	}
	
	
	/* TODO: Handle relationships */
	if([[entityLayout objectForKey:kDKEntityRelationshipsKey] count] > 0)
		NSLog(@"*** DatabaseKit: Relationships are not implemented.");
	
	
	//
	//	Here, we close the query.
	//
	[query appendString:@");"];
	
	return [self executeUpdateSQL:query error:error];
}

- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error
{
	if(![self tableExistsInDatabaseByName:kPKDatabaseConfigurationTableName])
	{
		NSString *query = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (databaseVersion FLOAT NOT NULL, databaseKitVersion FLOAT NOT NULL);", kPKDatabaseConfigurationTableName, [layout databaseVersion]];
		if(![self executeUpdateSQL:query error:error])
			return NO;
		
		query = [NSString stringWithFormat:@"INSERT INTO %@ (databaseVersion, databaseKitVersion) VALUES(%f, 1.0);", kPKDatabaseConfigurationTableName, [layout databaseVersion]];
		if(![self executeUpdateSQL:query error:error])
			return NO;
	}
	
	for (NSDictionary *entity in [layout entities])
	{
		NSString *entityName = [entity objectForKey:kDKEntityNameKey];
		if(![self tableExistsInDatabaseByName:entityName])
		{
			if(![self _createTableWithEntityLayoutDescription:entity error:error])
				return NO;
		}
	}
	
	return YES;
}

@end
