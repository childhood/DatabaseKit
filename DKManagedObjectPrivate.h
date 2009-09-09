/*
 *  DKManagedObjectPrivate.h
 *  DatabaseKit
 *
 *  Created by Peter MacWhinnie on 9/5/09.
 *  Copyright 2009 Roundabout Software. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "DKManagedObject.h"

@class DKAttributeDescription, DKRelationshipDescription;

//! @abstract	The private interface continuation for DKManagedObject.
@interface DKManagedObject () //Continuation

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
#pragma mark Accessor/Mutators

/*!
 @method
 @abstract	Set the value for a specified attribute in the receiver's database row.
 @param		value					The value to set. May be nil.
 @param		attributeDescription	The attribute to assign the value to. May not be nil.
 */
- (void)setValue:(id)value forAttribute:(DKAttributeDescription *)attributeDescription;

/*!
 @method
 @abstract	Look up the value for a specified attribute in the receiver's database row.
 @param		attributeDescription	The attribute to look up the value for. May not be nil.
 @result	The value of the attribute. This may be nil.
 */
- (id)valueForAttribute:(DKAttributeDescription *)attributeDescription;

#pragma mark -

- (void)setValue:(id)value forRelationship:(DKRelationshipDescription *)relationshipDescription;
- (id)valueForRelationship:(DKRelationshipDescription *)relationshipDescription;

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
 @param		key		The key of the value to look up. May not be nil.
 @result	The value associated with the specified key if it is cached; nil otherwise.
 */
- (id)cachedValueForKey:(NSString *)key;

/*!
 @method
 @abstract		Cache the values of all of the receiver's columns specified by its table description.
 @discussion	This method is used to implement fetching of objects as non-promises.
 */
- (void)cacheAllColumnsInTable;

#pragma mark -

/*!
 @method
 @abstract		Remove the cached value associated with a specified key.
 @param			key		The key of the value whose cache is to be removed. May not be nil.
 @discussion	This method does nothing if there is no cache for the value specified by the key.
 */
- (void)removeCacheForKey:(NSString *)key;

/*!
 @method
 @abstract	Invalidate a database object's internal cache.
 */
- (void)invalidateCache;
@end
