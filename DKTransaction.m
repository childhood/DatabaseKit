//
//  DKTransaction.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKTransaction.h"
#import "DKTransactionPrivate.h"
#import "DKDatabase.h"

@implementation DKTransaction

@synthesize database = mDatabase;

#pragma mark -

/*!
 @method
 @abstract	This method is called to clean up the receiver's resources in both garbage collected, and non-collected environments.
 */
- (void)cleanUp
{
	if(mCurrentStatement)
	{
		sqlite3_finalize(mCurrentStatement);
		mCurrentStatement = NULL;
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

- (id)initWithDatabase:(DKDatabase *)database
{
	if((self = [super init]))
	{
		mDatabase = database;
		mSQLHandle = database.sqliteHandle;
		
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Database Interaction

- (BOOL)compileSQLStatement:(NSString *)statement error:(NSError **)error
{
	NSParameterAssert(statement);
	
	if(mCurrentStatement)
	{
		sqlite3_finalize(mCurrentStatement);
		mCurrentStatement = NULL;
	}
	
	int status = sqlite3_prepare_v2(mSQLHandle, //in SQLite3 handle
									[statement UTF8String], //in cleanQuery
									-1, //in byteOffset
									&mCurrentStatement, //out compiledStatement
									NULL); //out unusedStatementBytes
	if(status != SQLITE_OK)
	{
		if(error) *error = DKLocalizedError(DKGeneralErrorDomain, 
											status, 
											nil, 
											@"Could not prepare statement", statement, status, error);
		return NO;
	}
	
	return YES;
}

- (BOOL)executeSQLStatement:(NSString *)statement error:(NSError **)error
{
	char *errorMessage = NULL;
	int status = SQLITE_OK;
	if((status = sqlite3_exec(mSQLHandle, //in SQLite3 handle
							  [statement UTF8String], //in cleanQuery
							  NULL, //in callback
							  NULL, //in callbackUserData
							  &errorMessage /* out bycopy errorMessage */)) != SQLITE_OK)
	{
		if(error) *error = DKLocalizedError(DKGeneralErrorDomain, 
											status, 
											nil, 
											@"Update query failed", statement, status, errorMessage);
		
		sqlite3_free(errorMessage);
		
		return NO;
	}
	
	return YES;
}

- (int)evaluateStatement
{
	NSAssert((mCurrentStatement != NULL), @"Attempting to operate on transaction without an active statement.");
	
	return sqlite3_step(mCurrentStatement);
}

#pragma mark -

- (void)setNullForColumnAtIndex:(int)columnIndex
{
	int status = sqlite3_bind_null(mCurrentStatement, columnIndex);
	
	NSAssert((status == SQLITE_OK), 
			 @"Remove value for column %d. Got error %d \"%s\".", columnIndex, status, sqlite3_errmsg(mSQLHandle));
}

#pragma mark -

- (void)setString:(NSString *)string forColumnAtIndex:(int)columnIndex
{
	NSAssert((mCurrentStatement != NULL), @"Attempting to operate on transaction without an active statement.");
	NSParameterAssert(string);
	
	int status = sqlite3_bind_text(mCurrentStatement, //in statement
								   columnIndex, //in columnIndex
								   [string UTF8String], //in stringData
								   [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], //in stringDataLength
								   SQLITE_STATIC); //in dataDestructor
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set string for column %d. Got error %d \"%s\".", columnIndex, status, sqlite3_errmsg(mSQLHandle));
}

- (NSString *)stringForColumnAtIndex:(int)columnIndex
{
	const char *cStringData = (const char *)sqlite3_column_text(mCurrentStatement, columnIndex);
	if(cStringData)
		return [NSString stringWithUTF8String:cStringData];
	
	return nil;
}

- (void)setDate:(NSDate *)date forColumnAtIndex:(int)columnIndex
{
	NSAssert((mCurrentStatement != NULL), @"Attempting to operate on transaction without an active statement.");
	NSParameterAssert(date);
	
	//The DATETIME type expects values to be in the form of YY-MM-DD HH:MM:SS.MMM.
	NSString *dateString = [date descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S.%F" timeZone:nil locale:nil];
	int status = sqlite3_bind_text(mCurrentStatement, //in statement
								   columnIndex, //in columnIndex
								   [dateString UTF8String], //in stringData
								   [dateString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], //in stringDataLength
								   SQLITE_STATIC); //in dataDestructor
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set date for column %d. Got error %d \"%s\".", columnIndex, status, sqlite3_errmsg(mSQLHandle));
}

- (NSDate *)dateForColumnAtIndex:(int)columnIndex
{
	const char *cStringData = (const char *)sqlite3_column_text(mCurrentStatement, columnIndex);
	if(cStringData)
	{
		NSString *dateString = [NSString stringWithUTF8String:cStringData];
		return [NSDate dateWithString:dateString];
	}
	
	return nil;
}

#pragma mark -

- (void)setInt:(int)value forColumnAtIndex:(int)columnIndex
{
	NSAssert((mCurrentStatement != NULL), @"Attempting to operate on transaction without an active statement.");
	
	int status = sqlite3_bind_int(mCurrentStatement, //in statement
								  columnIndex, //in columnIndex
								  value); //in value
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set int for column %d. Got error %d \"%s\".", columnIndex, status, sqlite3_errmsg(mSQLHandle));
}

- (int)intForColumnAtIndex:(int)columnIndex
{
	return sqlite3_column_int(mCurrentStatement, columnIndex);
}

- (void)setLongLong:(long long)value forColumnAtIndex:(int)columnIndex
{
	NSAssert((mCurrentStatement != NULL), @"Attempting to operate on transaction without an active statement.");
	
	int status = sqlite3_bind_int64(mCurrentStatement, //in statement
									columnIndex, //in columnIndex
									value); //in value
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set long long for column %d. Got error %d \"%s\".", columnIndex, status, sqlite3_errmsg(mSQLHandle));
}

- (long long)longLongForColumnAtIndex:(int)columnIndex
{
	return sqlite3_column_int64(mCurrentStatement, columnIndex);
}

- (void)setDouble:(double)value forColumnAtIndex:(int)columnIndex
{
	NSAssert((mCurrentStatement != NULL), @"Attempting to operate on transaction without an active statement.");
	
	int status = sqlite3_bind_double(mCurrentStatement, //in statement
									 columnIndex, //in columnIndex
									 value); //in value
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set double for column %d. Got error %d \"%s\".", columnIndex, status, sqlite3_errmsg(mSQLHandle));
}

- (double)doubleForColumnAtIndex:(int)columnIndex
{
	return sqlite3_column_double(mCurrentStatement, columnIndex);
}

#pragma mark -

- (void)setData:(NSData *)data forColumnAtIndex:(int)columnIndex
{
	NSAssert((mCurrentStatement != NULL), @"Attempting to operate on transaction without an active statement.");
	NSParameterAssert(data);
	
	int status = sqlite3_bind_blob(mCurrentStatement, //in statement
								   columnIndex, //in columnIndex
								   [data bytes], //in blobBytes
								   [data length], //in blobLength
								   SQLITE_STATIC); //in dataDestructor
	
	NSAssert((status == SQLITE_OK), 
			 @"Could not set data for column %d. Got error %d \"%s\".", columnIndex, status, sqlite3_errmsg(mSQLHandle));
}

- (NSData *)dataForColumnAtIndex:(int)columnIndex
{
	const void *blobBytes = sqlite3_column_blob(mCurrentStatement, columnIndex);
	int lengthOfBlob = sqlite3_column_bytes(mCurrentStatement, columnIndex);
	if(!blobBytes || (lengthOfBlob == 0))
		return [NSData data];
	
	return [NSData dataWithBytes:blobBytes length:lengthOfBlob];
}

- (void)setObject:(id)object forColumnAtIndex:(int)columnIndex
{
	NSParameterAssert(object);
	
	[self setData:[NSKeyedArchiver archivedDataWithRootObject:object] forColumnAtIndex:columnIndex];
}

- (id)objectForColumnAtIndex:(int)columnIndex
{
	return [NSKeyedUnarchiver unarchiveObjectWithData:[self dataForColumnAtIndex:columnIndex]];
}

@end
