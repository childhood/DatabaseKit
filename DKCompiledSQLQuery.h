//
//  DKSQLStatement.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/7/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <sqlite3.h>

@class DKDatabase;
@interface DKCompiledSQLQuery : NSObject
{
	/* strong */	DKDatabase *mDatabase;
	/* weak */		sqlite3 *mSQLConnection;
	/* owner */		sqlite3_stmt *mSQLStatement;
}
- (id)initWithQuery:(NSString *)query database:(DKDatabase *)database error:(NSError **)error;

#pragma mark -
#pragma mark Evaluation

- (BOOL)evaluateAndReturnError:(NSError **)error;
- (BOOL)nextRow;

#pragma mark -
#pragma mark Column Accessor/Mutators

- (void)nullifyColumnAtIndex:(int)columnIndex;

#pragma mark -

- (void)setString:(NSString *)string forColumnAtIndex:(int)columnIndex;
- (NSString *)stringForColumnAtIndex:(int)columnIndex;

- (void)setDate:(NSDate *)date forColumnAtIndex:(int)columnIndex;
- (NSDate *)dateForColumnAtIndex:(int)columnIndex;

#pragma mark -

- (void)setInt:(int)value forColumnAtIndex:(int)columnIndex;
- (int)intForColumnAtIndex:(int)columnIndex;

- (void)setLongLong:(long long)value forColumnAtIndex:(int)columnIndex;
- (long long)longLongForColumnAtIndex:(int)columnIndex;

- (void)setDouble:(double)value forColumnAtIndex:(int)columnIndex;
- (double)doubleForColumnAtIndex:(int)columnIndex;
#pragma mark -

- (void)setData:(NSData *)data forColumnAtIndex:(int)columnIndex;
- (NSData *)dataForColumnAtIndex:(int)columnIndex;

- (void)setObject:(id)object forColumnAtIndex:(int)columnIndex;
- (id)objectForColumnAtIndex:(int)columnIndex;
@end
