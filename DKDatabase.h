//
//  DKDatabase.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <sqlite3.h>
#import <dispatch/dispatch.h>

@protocol DKDatabaseLayout;
@class DKFetchRequest, DKTransaction, DKTableDescription;

@interface DKDatabase : NSObject
{
@package
	/* owner */	sqlite3 *mSQLiteHandle;
	/* owner */	id < DKDatabaseLayout > mDatabaseLayout;
	/* owner */	dispatch_queue_t mTransactionQueue;
}
- (id)initWithDatabaseAtURL:(NSURL *)location layout:(id < DKDatabaseLayout >)layout error:(NSError **)error;

@property (readonly) sqlite3 *sqliteHandle;

@property (readonly) id < DKDatabaseLayout > databaseLayout;

- (BOOL)tableExistsWithName:(NSString *)name;
- (void)transaction:(void(^)(DKTransaction *transaction))handler;

- (NSArray *)executeFetchRequest:(DKFetchRequest *)fetchRequest error:(NSError **)error;

@end
