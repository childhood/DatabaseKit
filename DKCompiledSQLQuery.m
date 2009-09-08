//
//  DKSQLStatement.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/7/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKCompiledSQLQuery.h"
#import "DKDatabase.h"
#import "DKDatabasePrivate.h"

@implementation DKCompiledSQLQuery

#pragma mark Destruction

- (void)cleanUp
{
	if(mSQLStatement)
	{
		sqlite3_finalize(mSQLStatement);
		mSQLStatement = NULL;
	}
}

- (void)finalize
{
	[self cleanUp];
	[super finalize];
}

- (void)dealloc
{
	[self cleanUp];
	
	[mDatabase release];
	mDatabase = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Construction

- (id)initWithQuery:(NSString *)query database:(DKDatabase *)database error:(NSError **)error
{
	NSParameterAssert(query);
	NSParameterAssert(database);
	
	if((self = [super init]))
	{
		mDatabase = [database retain];
		mSQLConnection = database.sqliteConnection;
		
		SQLiteStatus status = sqlite3_prepare_v2(mSQLConnection, //in SQLite3 handle
												 [query UTF8String], //in cleanQuery
												 -1, //in byteOffset
												 &mSQLStatement, //out compiledStatement
												 NULL); //out unusedStatementBytes
		if(status != SQLITE_OK)
		{
			if(error) *error = DKLocalizedError(DKInitializationErrorDomain, 
												status, 
												nil, 
												@"Could not prepare statement", query, status, error);
			return NO;
		}
		
		return self;
	}
	return nil;
}

- (BOOL)evaluateAndReturnError:(NSError **)error
{
	SQLiteStatus status = sqlite3_step(mSQLStatement);
	if((status != SQLITE_OK) && (status != SQLITE_DONE))
	{
		if(error) *error = DKLocalizedError(DKEvaluationErrorDomain, 
											status, 
											nil, 
											@"%s", sqlite3_errmsg(mSQLConnection));
		return NO;
	}
	
	return YES;
}

- (BOOL)nextRow
{
	return (sqlite3_step(mSQLStatement) == SQLITE_ROW);
}

#pragma mark -
#pragma mark Column Accessor/Mutators

- (void)nullifyParameterAtIndex:(int)index
{
	SQLiteStatus status = sqlite3_bind_null(mSQLStatement, index);
	
	NSAssert((status == SQLITE_OK), 
			 @"Remove value for column %d. Got error %d \"%s\".", index, status, sqlite3_errmsg(mSQLConnection));
}

#pragma mark -

- (void)setString:(NSString *)string forParameterAtIndex:(int)index
{
	NSParameterAssert(string);
	
	SQLiteStatus status = sqlite3_bind_text(mSQLStatement, //in statement
											index, //in index
											[string UTF8String], //in stringData
											[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], //in stringDataLength
											SQLITE_STATIC); //in dataDestructor
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set string for column %d. Got error %d \"%s\".", index, status, sqlite3_errmsg(mSQLConnection));
}

- (NSString *)stringForColumnAtIndex:(int)index
{
	const char *cStringData = (const char *)sqlite3_column_text(mSQLStatement, index);
	if(cStringData)
		return [NSString stringWithUTF8String:cStringData];
	
	return nil;
}

- (void)setDate:(NSDate *)date forParameterAtIndex:(int)index
{
	NSParameterAssert(date);
	
	//The DATETIME type expects values to be in the form of YY-MM-DD HH:MM:SS.MMM.
	NSString *dateString = [date descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S.%F" timeZone:nil locale:nil];
	SQLiteStatus status = sqlite3_bind_text(mSQLStatement, //in statement
											index, //in index
											[dateString UTF8String], //in stringData
											[dateString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], //in stringDataLength
											SQLITE_STATIC); //in dataDestructor
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set date for column %d. Got error %d \"%s\".", index, status, sqlite3_errmsg(mSQLConnection));
}

- (NSDate *)dateForColumnAtIndex:(int)index
{
	const char *cStringData = (const char *)sqlite3_column_text(mSQLStatement, index);
	if(cStringData)
	{
		NSString *dateString = [NSString stringWithUTF8String:cStringData];
		return [NSDate dateWithString:dateString];
	}
	
	return nil;
}

#pragma mark -

- (void)setInt:(int)value forParameterAtIndex:(int)index
{
	SQLiteStatus status = sqlite3_bind_int(mSQLStatement, //in statement
										   index, //in index
										   value); //in value
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set int for column %d. Got error %d \"%s\".", index, status, sqlite3_errmsg(mSQLConnection));
}

- (int)intForColumnAtIndex:(int)index
{
	return sqlite3_column_int(mSQLStatement, index);
}

- (void)setLongLong:(long long)value forParameterAtIndex:(int)index
{
	SQLiteStatus status = sqlite3_bind_int64(mSQLStatement, //in statement
											 index, //in index
											 value); //in value
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set long long for column %d. Got error %d \"%s\".", index, status, sqlite3_errmsg(mSQLConnection));
}

- (long long)longLongForColumnAtIndex:(int)index
{
	return sqlite3_column_int64(mSQLStatement, index);
}

- (void)setDouble:(double)value forParameterAtIndex:(int)index
{
	SQLiteStatus status = sqlite3_bind_double(mSQLStatement, //in statement
											  index, //in index
											  value); //in value
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set double for column %d. Got error %d \"%s\".", index, status, sqlite3_errmsg(mSQLConnection));
}

- (double)doubleForColumnAtIndex:(int)index
{
	return sqlite3_column_double(mSQLStatement, index);
}

#pragma mark -

- (void)setData:(NSData *)data forParameterAtIndex:(int)index
{
	NSParameterAssert(data);
	
	SQLiteStatus status = sqlite3_bind_blob(mSQLStatement, //in statement
											index, //in index
											[data bytes], //in blobBytes
											[data length], //in blobLength
											SQLITE_STATIC); //in dataDestructor
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set data for column %d. Got error %d \"%s\".", index, status, sqlite3_errmsg(mSQLConnection));
}

- (NSData *)dataForColumnAtIndex:(int)index
{
	const void *blobBytes = sqlite3_column_blob(mSQLStatement, index);
	int lengthOfBlob = sqlite3_column_bytes(mSQLStatement, index);
	if(!blobBytes || (lengthOfBlob == 0))
		return [NSData data];
	
	return [NSData dataWithBytes:blobBytes length:lengthOfBlob];
}

- (void)setObject:(id)object forParameterAtIndex:(int)index
{
	NSParameterAssert(object);
	
	[self setData:[NSKeyedArchiver archivedDataWithRootObject:object] forParameterAtIndex:index];
}

- (id)objectForColumnAtIndex:(int)index
{
	return [NSKeyedUnarchiver unarchiveObjectWithData:[self dataForColumnAtIndex:index]];
}

@end
