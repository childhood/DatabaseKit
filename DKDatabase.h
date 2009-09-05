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

/*!
 @method
 @abstract	This class is used to represent databases in DatabaseKit.
 */
@interface DKDatabase : NSObject
{
@package
	/* owner */	sqlite3 *mSQLiteHandle;
	/* owner */	id < DKDatabaseLayout > mDatabaseLayout;
	/* owner */	NSOperationQueue *mTransactionQueue;
}
/*!
 @method
 @abstract		Initialize a database with a storage location and layout. Designated initializer.
 @param			location	A file URL describing the location the database should place its storage file. May be nil.
 @param			layout		An object describing the layout of the database. May not be nil.
 @param			Will contain an error if any problem occurs during initialization.
 @result		A fully initialized database object if no problems occur; nil otherwise.
 @discussion	Passing in a nil location will cause a transient database to be created.
 */
- (id)initWithDatabaseAtURL:(NSURL *)location layout:(id < DKDatabaseLayout >)layout error:(NSError **)error;

/*!
 @property
 @abstract	An object representing the layout of the database.
 */
@property (readonly) id < DKDatabaseLayout > databaseLayout;

#pragma mark -
#pragma mark Database Interaction

/*!
 @method
 @abstract	Check the existence of a table in the receiver's database.
 @param		name	The name of the table whose existence to test for. May not be nil.
 @result	YES if the table exists; NO otherwise.
 */
- (BOOL)tableExistsWithName:(NSString *)name;

/*!
 @method
 @abstract		Begin a transaction with a handler block.
 @param			handler		The block to invoke when a transaction is ready for use. May not be nil.
 @discussion	All operations on the database must be sent through this method.
				The handler block passed into this method is executed in a thread safe, exception safe context.
 */
- (void)transaction:(void(^)(DKTransaction *transaction))handler;

#pragma mark -

/*!
 @method
 @abstract	Returns an array of objects that meet the criteria specified by a given fetch request.
 @param		fetchRequest	A fetch request that specifies the search criteria for the fetch. May not be nil.
 @param		error			If there is a problem executing the fetch, upon return contains an instance of NSError that describes the problem.
 @result	A sorted array of objects that meet the criteria specified.
 */
- (NSArray *)executeFetchRequest:(DKFetchRequest *)fetchRequest error:(NSError **)error;

@end
