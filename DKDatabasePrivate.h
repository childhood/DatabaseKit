/*
 *  DKDatabasePrivate.h
 *  DatabaseKit
 *
 *  Created by Peter MacWhinnie on 9/5/09.
 *  Copyright 2009 Roundabout Software. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "DKDatabase.h"

/*!
 @const
 @abstract	The database configuration table's name.
 */
DK_EXTERN NSString *const kDKDatabaseConfigurationTableName;

/*!
 @const
 @abstract	The name of the table used to track the unique identifiers of tables.
 */
DK_EXTERN NSString *const kDKDatabaseSequenceTableName;

//! @abstract	The DKDatabase private continuation.
@interface DKDatabase () //Continuation

/*!
 @property
 @abstract		The SQLite handle of the database.
 @discussion	Direct interaction with this value is discouraged. Use a transaction whenever possible.
 */
@property (readonly) sqlite3 *sqliteConnection;


/*!
 @method
 @abstract	Update the receiver's tables to match a specified database layout.
 @param		layout	An object describing a database layout. May not be nil.
 @param		error	If the database layout cannot be updated, on return this will contain an error. May be nil.
 @result	YES if the database layout could be updated; NO otherwise.
 */
- (BOOL)ensureDatabaseIsUsingLayout:(id < DKDatabaseLayout >)layout error:(NSError **)error;


/*!
 @method
 @abstract	Fetch an unordered set of promise-database-objects from a specified table matching a specified query in the receiver.
 @param		table
				The table to look up the database objects in. May not be nil.
 @param		query
				The filter query to apply when looking up the values. May be nil.
 @param		returnsObjectsAsPromises
				If set to YES then the objects returned will have all of their properties precached.
 @param		error
				If the query fails, on return this will contain an error. May be nil.
 @result	An unordered set of objects if the fetch succeeds; nil otherwise.
 */
- (NSSet *)fetchObjectsInTable:(DKTableDescription *)table matchingQuery:(NSString *)query returnsObjectsAsPromises:(BOOL)returnsObjectsAsPromises error:(NSError **)error;

@end
