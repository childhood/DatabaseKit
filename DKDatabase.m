//
//  DKDatabase.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKDatabase.h"
#import "DKDatabaseLayout.h"

@interface DKDatabase () //Continuation

- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error;

@end

#pragma mark -

@implementation DKDatabase

@synthesize sqliteHandle = mSQLiteHandle;

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

#pragma mark -
#pragma mark Set up

- (BOOL)_createTableWithEntityLayoutDescription:(NSDictionary *)entityLayout error:(NSError **)error
{
	return NO;
}

- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error
{
	for (NSDictionary *entity in layout)
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
