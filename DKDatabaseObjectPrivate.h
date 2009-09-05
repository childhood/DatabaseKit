/*
 *  DKDatabaseObjectPrivate.h
 *  DatabaseKit
 *
 *  Created by Peter MacWhinnie on 9/5/09.
 *  Copyright 2009 Roundabout Software. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "DKDatabaseObject.h"

//! @abstract	The private interface continuation for DKDatabaseObject.
@interface DKDatabaseObject () //Continuation

#pragma mark Initialization

/*!
 @method
 @abstract		Initialize a database object with a unique identifier, table, and database.
 @param			uniqueIdentifier	The unique identifier of the entity in the database that this object represents. May not be nil.
 @param			table				The table that this object belongs to. May not be nil.
 @param			database			The database that owns this database object. May not be nil.
 @result		A database object representing the entity known by the passed in unique identifier.
 @discussion	This method is used to initialize database objects with existing entities in the database.
 */
- (id)initWithUniqueIdentifier:(int64_t)uniqueIdentifier table:(DKTableDescription *)table database:(DKDatabase *)database;

#pragma mark -
#pragma mark Cache

/*!
 @method
 @abstract	Cache the value for a specified key for later access.
 @param		value	The value to cache. May not be nil.
 @param		key		The key of the value. May not be nil. Will be copied.
 */
- (void)cacheValue:(id)value forKey:(NSString *)key;

/*!
 @method
 @abstract	Look up the cached value associated with a specified key.
 @param		key	The key of the value to look up. May not be nil.
 @result	The value associated with the specified key if it is cached; nil otherwise.
 */
- (id)cachedValueForKey:(NSString *)key;

#pragma mark -

/*!
 @method
 @abstract		Remove the cached value associated with a specified key.
 @param			key	The key of the value whose cache is to be removed. May not be nil.
 @discussion	This method does nothing if there is no cache for the value specified by the key.
 */
- (void)removeCacheForKey:(NSString *)key;

/*!
 @method
 @abstract	Invalidate a database object's internal cache.
 */
- (void)invalidateCache;
@end
