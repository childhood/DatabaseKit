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
@class DKFetchRequest, DKCompiledSQLQuery, DKTableDescription, DKManagedObject;

/*!
 @method
 @abstract	This class is used to represent databases in DatabaseKit.
 */
@interface DKDatabase : NSObject
{
@package
	/* owner */	sqlite3 *mSQLiteConnection;
	/* owner */	id < DKDatabaseLayout > mDatabaseLayout;
	/* owner */	NSURL *mLocation;
}
#pragma mark Initialization

/*!
 @method
 @abstract	DKDatabase's implementation of this method raises an exception. Use initWithDatabaseAtURL:layout:error: instead.
 @result	Never returns.
 */
- (id)init;

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

#pragma mark -
#pragma mark Database Attributes

/*!
 @property
 @abstract	An object representing the layout of the database.
 */
@property (readonly) id < DKDatabaseLayout > databaseLayout;

/*!
 @property
 @abstract		The location of the database.
 @discussion	This property will be nil if the database is transient.
 */
@property (readonly) NSURL *location;

/*!
 @property
 @abstract	The version of the database.
 */
@property (readonly) double databaseVersion;

#pragma mark -

/*!
 @method
 @abstract	Check the existence of a table in the receiver's database.
 @param		name	The name of the table whose existence to test for. May not be nil.
 @result	YES if the table exists; NO otherwise.
 */
- (BOOL)tableExistsWithName:(NSString *)name;

#pragma mark -
#pragma mark SQL Queries

/*!
 @method
 @abstract		Compile an SQL query for use with the receiver's SQLite connection.
 @param			query	The SQL query to compile. May not be nil.
 @param			error	If the query cannot be compiled this will contain an error. May be nil.
 @result		nil if an error occurs; a new autoreleased compiled SQL query.
 @discussion	This method should only be executed from within the context of a transaction.
 */
- (DKCompiledSQLQuery *)compileSQLQuery:(NSString *)query error:(NSError **)error;

/*!
 @method
 @abstract		Execute an SQL query on the receiver's SQLite connection.
 @param			query	The SQL query to execute. May not be nil.
 @param			error	If the query fails, this will contain an error on return. May be nil.
 @result		YES if the query could be executed; NO otherwise.
 @discussion	This method should only be executed from within the context of a transaction.
 */
- (BOOL)executeSQLQuery:(NSString *)query error:(NSError **)error;

#pragma mark -
#pragma mark Fetching

/*!
 @method
 @abstract	Returns an array of objects that meet the criteria specified by a given fetch request.
 @param		fetchRequest	A fetch request that specifies the search criteria for the fetch. May not be nil.
 @param		error			If there is a problem executing the fetch, upon return contains an instance of NSError that describes the problem.
 @result	A sorted array of objects that meet the criteria specified.
 */
- (NSArray *)executeFetchRequest:(DKFetchRequest *)fetchRequest error:(NSError **)error;

#pragma mark -
#pragma mark Managed Object Life Cycle

/*!
 @method
 @abstract		Insert a new object into a specified table returning the object.
 @param			table	The table to insert the new database object into. May not be nil.
 @param			error	If the insertion fails, this will contain an error. May be nil.
 @result		A new database object inserted into the specified table if successful; nil otherwise.
 @discussion	The value returned by this method is not autoreleased.
 */
- (id)insertNewObjectIntoTable:(DKTableDescription *)table error:(NSError **)error;

/*!
 @method
 @abstract		Delete a managed object from the receiver.
 @param			object	The managed object to delete. May not be nil.
 @discussion	The managed object passed in should be considered invalid after this method returns
				and all references should be destroyed.
 */
- (void)deleteObject:(DKManagedObject *)object;

#pragma mark -
#pragma mark Transactions

/*!
 @method
 @abstract	Begin a transaction in the receiver's SQL connection.
 */
- (void)beginTransaction;

/*!
 @method
 @abstract	Commit the top most transaction in the receiver's SQL connection.
 */
- (void)commitTransaction;

@end
