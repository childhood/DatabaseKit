//
//  DKDatabase.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <sqlite3.h>

@protocol DKDatabaseLayout;
@class DKTransactionManager;

@interface DKDatabase : NSObject
{
@package
	sqlite3 *mSQLiteHandle;
}
- (id)initWithDatabaseAtURL:(NSURL *)location layout:(id < DKDatabaseLayout >)layout error:(NSError **)error;

@property (readonly) sqlite3 *sqliteHandle;

@property (readonly) double databaseVersion;
@end
