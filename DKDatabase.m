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

#import "DKManagedObjectPrivate.h"
#import "DKManagedObject.h"

#import "DKCompiledSQLQuery.h"
#import "NSString+Database.h"

NSString *const kDKDatabaseConfigurationTableName = @"_DKDatabaseConfiguration";
NSString *const kDKDatabaseSequenceTableName = @"_DKTableSequence";
NSString *const kDKDatabaseRelationshipDescriptionTableName = @"_DKRelationshipDescription";

@implementation DKDatabase

#pragma mark Destruction

- (void)cleanUp
{
	if(mSQLiteConnection)
	{
		//Finalize any active statements.
		sqlite3_stmt *activeStatement = NULL;
		while ((activeStatement = sqlite3_next_stmt(mSQLiteConnection, 0)))
		{
			sqlite3_finalize(activeStatement);
		}
		
		//Close the database, and we're done.
		sqlite3_close(mSQLiteConnection);
		mSQLiteConnection = NULL;
	}
}

- (void)dealloc
{
	[self cleanUp];
	
	[mDatabaseLayout release];
	mDatabaseLayout = nil;
	
	[mLocation release];
	mLocation = nil;
	
	[super dealloc];
}

- (void)finalize
{
	[self cleanUp];
	[super finalize];
}

#pragma mark -
#pragma mark Construction

//! @abstract	Simply raises.
- (id)init
{
	[NSException raise:NSInvalidArgumentException format:@"Attempting to initialize a DKDatabase with init. Use initWithDatabaseAtURL:layout:error: instead."];
	
	return nil;
}

- (id)initWithDatabaseAtURL:(NSURL *)location layout:(id < DKDatabaseLayout >)layout error:(NSError **)error
{
	NSParameterAssert(layout);
	if(location)
		NSAssert([location isFileURL], @"Non-file URL %@ given.", location);
	
	if((self = [super init]))
	{
		SQLiteStatus status = SQLITE_OK;
		if(location)
		{
			NSString *path = [location path];
			
			//
			//	If the path has a : prefix, we prepend ./ to it so that
			//	it doesn't end up invoking a special function in sqlite.
			//
			if([path hasPrefix:@":"])
				path = [@"./" stringByAppendingString:path];
			
			status = sqlite3_open([path fileSystemRepresentation], &mSQLiteConnection);
		}
		else
		{
			//If we're given a nil location we create the database in memory.
			status = sqlite3_open(":memory:", &mSQLiteConnection);
		}
		
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
		mLocation = [location retain];
		
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Database Properties

@synthesize sqliteConnection = mSQLiteConnection;
@synthesize location = mLocation;

#pragma mark -

@synthesize databaseLayout = mDatabaseLayout;

@dynamic databaseVersion;
- (double)databaseVersion
{
	NSError *error = nil;
	
	//
	//	First we need to verify that the database configuration table is present in the database.
	//
	NSAssert([self ensureBuiltInTablesArePresentForLayout:mDatabaseLayout error:&error],
			 @"Could not create or update configuration table. Got error %@.", error);
	
	double version = 0.0;
	NSString *selectDatabaseVersionQueryString = [NSString stringWithFormat:@"SELECT databaseVersion FROM %@", kDKDatabaseConfigurationTableName];
	DKCompiledSQLQuery *selectDatabaseVersionQuery = [self compileSQLQuery:selectDatabaseVersionQueryString error:&error];
	NSAssert((selectDatabaseVersionQuery && [selectDatabaseVersionQuery nextRow]),
			 @"Could not find database version. Got error %@.", error);
	
	return [selectDatabaseVersionQuery doubleForColumnAtIndex:0];
}

#pragma mark -
#pragma mark Fetching

- (NSSet *)fetchObjectsInTable:(DKTableDescription *)table matchingQuery:(NSString *)query returnsObjectsAsPromises:(BOOL)returnsObjectsAsPromises error:(NSError **)error
{
	NSParameterAssert(table);
	
	NSString *escapedTableName = [table.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	//
	//	We create an SQL SELECT query based on the passed in partial query.
	//	If there is no partial query, we just select everything thats in
	//	`table` indiscriminately like a common whore.
	//
	NSString *selectQueryString = nil;
	if(query)
		selectQueryString = dk_string_from_format(
			dk_stringify_sql(
				SELECT _dk_uniqueIdentifier FROM %@ WHERE %@
			),
			escapedTableName, query
		);
	else
		selectQueryString = dk_string_from_format(
			dk_stringify_sql(
				SELECT _dk_uniqueIdentifier FROM %@
			),
			escapedTableName
		);
	
	//Execute the select query.
	DKCompiledSQLQuery *selectQuery = [self compileSQLQuery:selectQueryString error:error];
	if(!selectQuery)
		return nil;
	
	//
	//	We need to verify that the database-object-class the table specifies
	//	inherits from DKManagedObject. If it doesn't then we have a problem.
	//
	Class databaseObjectClass = table.databaseObjectClass;
	NSAssert(((databaseObjectClass == [DKManagedObject class]) || [databaseObjectClass isSubclassOfClass:[DKManagedObject class]]), 
			 @"Database object class %@ does not inherit DKManagedObject. You fail at life.", NSStringFromClass(databaseObjectClass));
	
	
	//
	//	We enumerate all of the rows returned by the select query
	//	and create a database-object for each given unique identifier.
	//
	NSMutableSet *objects = [NSMutableSet set];
	while ([selectQuery nextRow])
	{
		int64_t uniqueIdentifier = [selectQuery longLongForColumnAtIndex:0];
		
		id databaseObject = [[databaseObjectClass alloc] initWithUniqueIdentifier:uniqueIdentifier 
																			table:table 
																		 database:self];
		if(databaseObject)
		{
			[databaseObject awakeFromFetch];
			
			//
			//	If we've been asked to fulfill promises immediately then we
			//	tell each database object to cache all of their columns.
			//
			if(!returnsObjectsAsPromises)
				[databaseObject cacheAllColumnsInTable];
			
			[objects addObject:databaseObject];
		}
	}
	
	return objects;
}

- (NSArray *)executeFetchRequest:(DKFetchRequest *)fetchRequest error:(NSError **)error
{
	NSParameterAssert(fetchRequest);
	
	NSSet *objects = [self fetchObjectsInTable:fetchRequest.table 
								 matchingQuery:fetchRequest.filterString 
					  returnsObjectsAsPromises:fetchRequest.returnsObjectsAsPromises 
										 error:error];
	if(objects)
	{
		NSArray *sortDescriptors = fetchRequest.sortDescriptors;
		if(sortDescriptors)
			return [objects sortedArrayUsingDescriptors:sortDescriptors];
		
		return [objects allObjects];
	}
	return nil;
}

#pragma mark -
#pragma mark Inserting

- (id)insertNewObjectIntoTable:(DKTableDescription *)table error:(NSError **)error
{
	NSParameterAssert(table);
	
	NSError *transientError = nil;
	
	//The table name could very well contain single quotes so we escape it.
	NSString *escapedTableName = [table.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	//
	//	First things first, we need to fetch the last unique identifier from
	//	the database's internal sequence table. We use this to calculate the new
	//	unique identifier for the object we're about to insert.
	//
	NSString *selectOffsetQueryString = dk_string_from_format(
		dk_stringify_sql(
			SELECT offset FROM %@ WHERE name='%@'
		),
		kDKDatabaseSequenceTableName, escapedTableName
	);
	DKCompiledSQLQuery *selectOffsetQuery = [self compileSQLQuery:selectOffsetQueryString error:&transientError];
	if(!selectOffsetQuery)
		return nil;
	
	
	//
	//	If we find an entry in the database sequence describing the last unique identifier
	//	given to a row in `table` we increment that value by one and use that as the
	//	unique identifier of the row we're about to create. If we don't find an existing row
	//	then we're the first object to be inserted into this table and we use the identifier '0'.
	//
	int64_t newUniqueIdentifier = 0;
	if([selectOffsetQuery nextRow])
		newUniqueIdentifier = [selectOffsetQuery longLongForColumnAtIndex:0] + 1;
	
	
	//
	//	Its time to insert a new row into `table`. We pass in the unique identifier
	//	we just created and prey to someone's god that this works. If it does, it
	//	confirms our suspicions that there is no god. After all, what kind of god
	//	would insert a new row into our database, its not like it attends church.
	//
	NSString *insertNewRowQueryString = dk_string_from_format(
		dk_stringify_sql(
			INSERT INTO '%@' (_dk_uniqueIdentifier) VALUES (%lld)
		),
		escapedTableName, newUniqueIdentifier
	);
	DKCompiledSQLQuery *insertNewRowQuery = [self compileSQLQuery:insertNewRowQueryString error:&transientError];
	if(!insertNewRowQuery)
		return nil;
	
	//
	//	If the insertion was successful then the query should have one row waiting
	//	for us. If it doesn't the insertion failed and we're in a world of hurt.
	//
	NSAssert([insertNewRowQuery evaluateAndReturnError:&transientError], 
			 @"Could not create new row for table named %@. Got error %@.", table.name, transientError);
	
	NSString *updateLastUniqueIdentifierQueryString = dk_string_from_format(
		dk_stringify_sql(
			UPDATE %@ SET offset=%lld WHERE name='%@'
		),
		kDKDatabaseSequenceTableName, newUniqueIdentifier, escapedTableName
	);
	NSAssert([self executeSQLQuery:updateLastUniqueIdentifierQueryString error:&transientError],
			 @"Could not update unique identifier in DKDatabase internal state. Got error %@.", transientError);
	//
	//	We need to verify that the database-object-class the table specifies
	//	inherits from DKManagedObject. If it doesn't then we have a problem.
	//
	Class databaseObjectClass = table.databaseObjectClass;
	NSAssert(((databaseObjectClass == [DKManagedObject class]) || [databaseObjectClass isSubclassOfClass:[DKManagedObject class]]), 
			 @"Database object class %@ does not inherit DKManagedObject. You fail at life.", NSStringFromClass(databaseObjectClass));
	//
	//	Now that we have a nice new row in `table`, we can create a wrapper object for it.
	//	We use the database-object-class specified by `table`. It could be something other
	//	then DKManagedObject.
	//
	id databaseObject = [[databaseObjectClass alloc] initWithUniqueIdentifier:newUniqueIdentifier 
																		table:table 
																	 database:self];
	[databaseObject awakeFromInsertion];
	
	
	return databaseObject;
}

#pragma mark -
#pragma mark Deleting

- (void)deleteObject:(DKManagedObject *)object
{
	NSParameterAssert(object);
	
	//
	//	We let the managed object know that we're about to delete the row it
	//	represents from the database. If it doesn't like that, too bad.
	//
	[object prepareForDeletion];
	
	
	//
	//	We use a SQL DELETE statement with the object's unique identifier to remove the value
	//	it represents from the database. If this fails, something is wrong and we explode.
	//
	NSString *deleteQueryString = dk_string_from_format(
		dk_stringify_sql(
			DELETE FROM %@ WHERE _dk_uniqueIdentifier=%lld
		),
		[object.tableDescription.name stringByEscapingStringForLiteralUseInSQLQueries], object.uniqueIdentifier
	);
	NSError *error = nil;
	NSAssert([self executeSQLQuery:deleteQueryString error:&error],
			 @"Could not delete object %@. Got error %@.", error);
	
	
	//
	//	We're done with the object, release it.
	//
	[object release];
}

#pragma mark -
#pragma mark Database Queries

- (DKCompiledSQLQuery *)compileSQLQuery:(NSString *)query error:(NSError **)error
{
	return [[[DKCompiledSQLQuery alloc] initWithQuery:query database:self error:error] autorelease];
}

- (BOOL)executeSQLQuery:(NSString *)query error:(NSError **)error
{
	NSParameterAssert(query);
	
	char *errorMessage = NULL;
	int status = SQLITE_OK;
	if((status = sqlite3_exec(mSQLiteConnection, //in SQLite3 handle
							  [query UTF8String], //in cleanQuery
							  NULL, //in callback
							  NULL, //in callbackUserData
							  &errorMessage /* out bycopy errorMessage */)) != SQLITE_OK)
	{
		if(error) *error = DKLocalizedError(DKEvaluationErrorDomain, 
											status, 
											nil, 
											@"Update query failed", query, status, errorMessage);
		
		sqlite3_free(errorMessage);
		
		return NO;
	}
	
	return YES;
}

#pragma mark -

- (BOOL)tableExistsWithName:(NSString *)name
{
	NSString *tableInfoQueryString = dk_string_from_format(
		dk_stringify_sql(
			PRAGMA table_info(%@)
		), 
		[name stringByEscapingStringForLiteralUseInSQLQueries]
	);
	
	NSError *error = nil;
	DKCompiledSQLQuery *tableInfoQuery = [self compileSQLQuery:tableInfoQueryString error:&error];
	NSAssert((tableInfoQuery != nil),
			 @"Could not compile table info query. Got error %@.", error);
	
	return [tableInfoQuery nextRow];
}

#pragma mark -
#pragma mark Transactions

- (void)beginTransaction
{
	NSError *error = nil;
	NSAssert([self executeSQLQuery:dk_stringify_sql(BEGIN TRANSACTION) error:&error],
			 @"Could not begin transaction. Got error %@.", error);
}

- (void)commitTransaction
{
	NSError *error = nil;
	NSAssert([self executeSQLQuery:dk_stringify_sql(COMMIT TRANSACTION) error:&error],
			 @"Could not commit transaction. Got error %@.", error);
}

#pragma mark -
#pragma mark Database Setup

- (BOOL)ensureBuiltInTablesArePresentForLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error
{
	NSParameterAssert(layout);
	
	//
	//	We need to verify that the database configuration table is present in the database.
	//	This table contains the database version specified in the database layout as well as
	//	the version of DatabaseKit that created the database.
	//
	if(![self tableExistsWithName:kDKDatabaseConfigurationTableName])
	{
		NSString *createConfigurationTableQueryString = dk_string_from_format(
			dk_stringify_sql(
				CREATE TABLE IF NOT EXISTS %@ (
					databaseVersion FLOAT NOT NULL, 
					databaseKitVersion FLOAT NOT NULL
				)
			),
			kDKDatabaseConfigurationTableName, [layout databaseVersion]
		);
		if(![self executeSQLQuery:createConfigurationTableQueryString error:error])
			return NO;
		
		NSString *insertCurrentConfigurationQueryString = dk_string_from_format(
			dk_stringify_sql(
				INSERT INTO %@ (
					databaseVersion, 
					databaseKitVersion
				)
				VALUES(
					%f,
					1.0
				)
			),
			kDKDatabaseConfigurationTableName, [layout databaseVersion]
		);
		if(![self executeSQLQuery:insertCurrentConfigurationQueryString error:error])
			return NO;
		
	}
	
	
	//
	//	We also need to verify that the sequence table exists. Without this we
	//	can't track the unique identifier's of our database's tables.
	//
	if(![self tableExistsWithName:kDKDatabaseSequenceTableName])
	{
		//
		//	The sequence table is used to track the last unique identifier created for each
		//	table in the database, allowing us to fetch values we insert in DKManagedObject.
		//
		NSString *createDatabaseSequenceTableString = dk_string_from_format(
			dk_stringify_sql(
				CREATE TABLE IF NOT EXISTS %@ (
					name TEXT NOT NULL, 
					offset BIGINT DEFAULT(0)
				)
			),
			kDKDatabaseSequenceTableName
		);
		if(![self executeSQLQuery:createDatabaseSequenceTableString error:error])
			return NO;
	}
	
	
	//
	//	Lastly we need to make sure our table used for tracking relationships
	//	is present. If its not, relationships can't work.
	//
	if(![self tableExistsWithName:kDKDatabaseRelationshipDescriptionTableName])
	{
		//
		//	The relationship description table is used to track the two ends of a relationship.
		//
		NSString *createDatabaseRelationshipDescriptionTableString = dk_string_from_format(
			dk_stringify_sql(
				CREATE TABLE IF NOT EXISTS %@ (
					sourceKey TEXT NOT NULL, 
					sourceTable TEXT NOT NULL, 
					sourceID BIGINT NOT NULL, 
					destinationKey TEXT, 
					destinationTable TEXT NOT NULL, 
					destinationID BIGINT NOT NULL
				)
			),
			kDKDatabaseRelationshipDescriptionTableName
		);
		if(![self executeSQLQuery:createDatabaseRelationshipDescriptionTableString error:error])
			return NO;
	}
	
	return YES;
}

- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error
{
	NSParameterAssert(layout);
	
	//
	//	First we need to verify that the database configuration table is present in the database.
	//
	[self ensureBuiltInTablesArePresentForLayout:layout error:error];
	
	
	//
	//	We enumerate the tables described in the database layout and attempt
	//	to create each one. We also insert the initial table sequence value
	//	here as well.
	//
	for (DKTableDescription *table in [layout tables])
	{
		NSString *tableName = [table.name stringByEscapingStringForLiteralUseInSQLQueries];
		BOOL tableExisted = [self tableExistsWithName:tableName];
		
		if(![self createTableWithDescriptionIfAbsent:table error:error])
			return NO;
		
		if(!tableExisted)
		{
			NSString *insertInitialSequenceForTableQueryString = dk_string_from_format(
				dk_stringify_sql(
					INSERT OR IGNORE INTO %@ (
						name, 
						offset
					)
					VALUES(
						'%@', 
						0
					)
				),
				kDKDatabaseSequenceTableName, tableName
			);
			if(![self executeSQLQuery:insertInitialSequenceForTableQueryString error:error])
				return NO;
		}
	}
	
	return YES;
}

#pragma mark -

- (BOOL)createTableWithDescriptionIfAbsent:(DKTableDescription *)tableDescription error:(NSError **)error
{
	NSParameterAssert(tableDescription);
	
	NSString *escapedTableName = [tableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	//
	//	Create the base query. All tables created by DatabaseKit have
	//	a uuid column. This can be used to safely identify values in the
	//	database across application launches.
	//
	NSMutableString *createTableQueryString = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS '%@' (_dk_uniqueIdentifier BIGINT PRIMARY KEY NOT NULL", escapedTableName];
	
	
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
			[createTableQueryString appendFormat:@", %@ %@", [attribute.name stringByEscapingStringForLiteralUseInSQLQueries], DKAttributeTypeToSQLiteType(attributeType)];
			
			
			//
			//	If an attribute is required, we append the NOT NULL column constraint.
			//
			if(attribute.isRequired)
				[createTableQueryString appendString:@" NOT NULL"];
			
			
			//
			//	Currently default value is only supported for string/float/integer/int*
			//	columns. Attempting to give a default value to anything else will do nothing.
			//
			NSString *defaultValue = attribute.defaultValue;
			if(defaultValue)
			{
				if(attributeType == DKAttributeTypeString)
				{
					[createTableQueryString appendFormat:@" DEFAULT('%@')", [defaultValue stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
				}
				else if(attributeType == DKAttributeTypeFloat)
				{
					[createTableQueryString appendFormat:@" DEFAULT(%f)", [defaultValue doubleValue]];
				}
				else if((attributeType >= DKAttributeTypeInteger) && (attributeType <= DKAttributeTypeInt64))
				{
					[createTableQueryString appendFormat:@" DEFAULT(%lld)", [defaultValue longLongValue]];
				}
				else
				{
					NSLog(@"*** DatabaseKit: Type %d does not support default values.", attributeType);
				}
			}
		}
		else if([property isKindOfClass:[DKRelationshipDescription class]])
		{
			/* TODO: Implement relationships. */
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
	[createTableQueryString appendString:@");"];
	
	return [self executeSQLQuery:createTableQueryString error:error];
}

@end
