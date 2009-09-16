//
//  DKManagedObject.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKManagedObject.h"
#import "DKManagedObjectPrivate.h"

#import "DKDatabase.h"
#import "DKDatabasePrivate.h"

#import "DKTableDescription.h"
#import "DKCompiledSQLQuery.h"

#import "NSString+Database.h"

#import <sqlite3.h>
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

@implementation DKManagedObject

- (void)dealloc
{
	if(_dk_mCachedValues)
	{
		[_dk_mCachedValues release];
		_dk_mCachedValues = nil;
	}
	
	[super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (id)initWithUniqueIdentifier:(int64_t)uniqueIdentifier table:(DKTableDescription *)table database:(DKDatabase *)database
{
	NSParameterAssert(database);
	
	if((self = [super init]))
	{
		_dk_mUniqueIdentifier = uniqueIdentifier;
		_dk_mTableDescription = table;
		_dk_mDatabase = database;
		
		_dk_mCachedValues = [NSMutableDictionary new];
		_dk_mExtraRetainCount = 1;
		
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Life Cycle Methods

//
//	The life cycle of DKManagedObject is controlled by DKDatabase. It only tracks its retain count
//	for the purpose of controlling cache. That is, if a managed object has a retain count of 1 it
//	is eligible for removal from local database cache.
//
- (oneway void)release
{
	//
	//	Release does nothing if extra-retain-count is 1. We are simply tracking
	//	this value for the purposes of cache-life-cycle management.
	//
	OSMemoryBarrier();
	if(_dk_mExtraRetainCount > 1)
	{
#if __LP64__ || NS_BUILD_32_LIKE_64
		OSAtomicDecrement64((volatile int64_t *)&_dk_mExtraRetainCount);
#else
		OSAtomicDecrement32((volatile int32_t *)&_dk_mExtraRetainCount);
#endif /* __LP64__ || NS_BUILD_32_LIKE_64 */
	}
}

- (id)retain
{
#if __LP64__ || NS_BUILD_32_LIKE_64
	OSAtomicIncrement64((volatile int64_t *)&_dk_mExtraRetainCount);
#else
	OSAtomicIncrement32((volatile int32_t *)&_dk_mExtraRetainCount);
#endif /* __LP64__ || NS_BUILD_32_LIKE_64 */
	
	return self;
}

- (NSUInteger)retainCount
{
	OSMemoryBarrier();
	return _dk_mExtraRetainCount;
}

#pragma mark -
#pragma mark Accessor/Mutator Generation

static void _DKManagedObject_SetCallback(DKManagedObject *self, SEL _cmd, id value)
{
	NSMutableString *columnName = [NSMutableString stringWithString:NSStringFromSelector(_cmd)];
	
	//Remove the set prefix
	[columnName deleteCharactersInRange:NSMakeRange(0, 3)];
	
	//Remove the : suffix
	[columnName deleteCharactersInRange:NSMakeRange([columnName length] - 1, 1)];
	
	//Downcase the first character
	[columnName replaceCharactersInRange:NSMakeRange(0, 1) withString:[[columnName substringToIndex:1] lowercaseString]];
	
	[self setValue:value forColumnNamed:columnName];
}

static id _DKManagedObject_GetCallback(DKManagedObject *self, SEL _cmd)
{
	NSString *columnName = NSStringFromSelector(_cmd);
	return [self valueForColumnNamed:columnName];
}

#pragma mark -

+ (void)addAccessorMutatorPairForProperty:(DKPropertyDescription *)property
{
	NSParameterAssert(property);
	
	NSString *propertyName = property.name;
	
	SEL accessorSelector = NSSelectorFromString(propertyName);
	SEL mutatorSelector = NSSelectorFromString([NSString stringWithFormat:@"set%C%@:", toupper([propertyName characterAtIndex:0]), [propertyName substringFromIndex:1]]);
	
	if(!class_getInstanceMethod(self, mutatorSelector))
		class_addMethod(self, mutatorSelector, (IMP)&_DKManagedObject_SetCallback, "v@:@");
	
	if(!class_getInstanceMethod(self, accessorSelector))
		class_addMethod(self, accessorSelector, (IMP)&_DKManagedObject_GetCallback, "@@:");
}

#pragma mark -
#pragma mark Properties

@synthesize database = _dk_mDatabase;
@synthesize tableDescription = _dk_mTableDescription;
@synthesize uniqueIdentifier = _dk_mUniqueIdentifier;

#pragma mark -
#pragma mark Cache Management

- (void)cacheValue:(id)value forKey:(NSString *)key
{
	@synchronized(self)
	{
		[_dk_mCachedValues setObject:value forKey:key];
	}
}

- (id)cachedValueForKey:(NSString *)key
{
	@synchronized(self)
	{
		return [_dk_mCachedValues objectForKey:key];
	}
}

- (void)cacheAllColumnsInTable
{
	//
	//	We enumerate all of the properties in our table description.
	//	By asking ourselves for the value of the each property we
	//	build a local cache of the row this object represents in the database.
	//
	for (DKPropertyDescription *property in _dk_mTableDescription.properties)
		[self valueForColumnNamed:property.name];
}

#pragma mark -

- (void)removeCacheForKey:(NSString *)key
{
	@synchronized(self)
	{
		[_dk_mCachedValues removeObjectForKey:key];
	}
}

- (void)invalidateCache
{
	@synchronized(self)
	{
		[_dk_mCachedValues removeAllObjects];
	}
}

#pragma mark -
#pragma mark Database Accessor/Mutators

- (void)setValue:(id)value forAttribute:(DKAttributeDescription *)attributeDescription
{
	NSParameterAssert(attributeDescription);
	if(attributeDescription.isRequired)
		NSParameterAssert(value);
	
	NSError *error = nil;
	
	//We escape these values to prevent SQL injection.
	NSString *escapedAttributeName = [attributeDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	NSString *escapedTableName = [_dk_mTableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	//
	//	We create an SQL UPDATE query to update the value associated with `key`.
	//	We determine the row to update in `table` by our unique identifier.
	//
	//	Note that we use a ? so we don't have to escape the value. We set it directly
	//	in the switch statement below.
	//
	NSString *updateQueryString = dk_string_from_format(
		dk_stringify_sql(
			UPDATE %@ SET '%@' = ? WHERE _dk_uniqueIdentifier=%lld
		),
		escapedTableName, escapedAttributeName, _dk_mUniqueIdentifier
	);
	
	//Evaluate the update query.
	DKCompiledSQLQuery *updateQuery = [_dk_mDatabase compileSQLQuery:updateQueryString error:&error];
	NSAssert((updateQuery != nil), 
			 @"Could not compile update query. Got error %@.", error);
	
	
	if(value)
	{
		//
		//	If value isn't nil we set the value of the first column in the query (key)
		//	based on the type described in the attribute description for the specified key.
		//
		switch (attributeDescription.type)
		{
			case DKAttributeTypeString:
				[updateQuery setString:value forParameterAtIndex:1];
				break;
				
			case DKAttributeTypeDate:
				[updateQuery setDate:value forParameterAtIndex:1];
				break;
				
			case DKAttributeTypeInt8:
			case DKAttributeTypeInt16:
			case DKAttributeTypeInt32:
				[updateQuery setInt:[value intValue] forParameterAtIndex:1];
				break;
				
			case DKAttributeTypeInt64:
				[updateQuery setLongLong:[value longLongValue] forParameterAtIndex:1];
				break;
				
			case DKAttributeTypeFloat:
				[updateQuery setDouble:[value doubleValue] forParameterAtIndex:1];
				break;
				
			case DKAttributeTypeData:
				[updateQuery setData:value forParameterAtIndex:1];
				break;
				
			case DKAttributeTypeObject:
				[updateQuery setObject:value forParameterAtIndex:1];
				break;
				
			default:
				//This should never happen, but if it does we just write null.
				[updateQuery nullifyParameterAtIndex:1];
				break;
		}
	}
	else
	{
		[updateQuery nullifyParameterAtIndex:1];
	}
	
	
	//
	//	This is where the actual update happens. If it doesn't work,
	//	we fail catastrophically. Because really, who wants to fail nicely.
	//
	NSAssert([updateQuery evaluateAndReturnError:&error], 
			 @"Could not update value for key %@. Got error %@.", attributeDescription.name, error);
}

- (id)valueForAttribute:(DKAttributeDescription *)attributeDescription
{
	NSParameterAssert(attributeDescription);
	
	NSError *error = nil;
	
	//We escape these values to prevent SQL injection.
	NSString *escapedAttributeName = [attributeDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	NSString *escapedTableName = [_dk_mTableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	//
	//	We create an SQL SELECT query to find the value specified by `key` in
	//	our row in the database. We find ourselves using our unique identifier.
	//
	NSString *selectQueryString = dk_string_from_format(
		dk_stringify_sql(
			SELECT %@ FROM %@ WHERE(_dk_uniqueIdentifier=%lld)
		),
		escapedAttributeName, escapedTableName, _dk_mUniqueIdentifier
	);
	
	
	//Evaluate the update query.
	DKCompiledSQLQuery *selectQuery = [_dk_mDatabase compileSQLQuery:selectQueryString error:&error];
	NSAssert((selectQuery != nil), 
			 @"Could not compile select query. Got error %@.", error);
	
	//
	//	The first row of the select query should contain the value specified by `key`.
	//	If it doesn't its value is nil and we're just going to return that.
	//
	if(![selectQuery nextRow])
		return nil;
	
	
	//
	//	We convert the returned value from the query to an object using
	//	the type specified by `attributeDescription` to decide what to create.
	//
	id value = nil;
	switch (attributeDescription.type)
	{
		case DKAttributeTypeString:
			value = [selectQuery stringForColumnAtIndex:0];
			break;
			
		case DKAttributeTypeDate:
			value = [selectQuery dateForColumnAtIndex:0];
			break;
			
		case DKAttributeTypeInt8:
		case DKAttributeTypeInt16:
		case DKAttributeTypeInt32:
			value = [NSNumber numberWithInt:[selectQuery intForColumnAtIndex:0]];
			break;
			
		case DKAttributeTypeInt64:
			value = [NSNumber numberWithLongLong:[selectQuery longLongForColumnAtIndex:0]];
			break;
			
		case DKAttributeTypeFloat:
			value = [NSNumber numberWithDouble:[selectQuery doubleForColumnAtIndex:0]];
			break;
			
		case DKAttributeTypeData:
			value = [selectQuery dataForColumnAtIndex:0];
			break;
			
		case DKAttributeTypeObject:
			value = [selectQuery objectForColumnAtIndex:0];
			break;
			
		default:
			break;
	}
	
	return value;
}

#pragma mark -

- (void)setValue:(id)value forRelationship:(DKRelationshipDescription *)relationshipDescription
{
	NSParameterAssert(relationshipDescription);
	
	//We only require value to be non-nil if the relationship denotes it.
	if(relationshipDescription.isRequired)
		NSParameterAssert(value);
	
	NSError *error = nil;
	DKRelationshipType relationshipType = relationshipDescription.relationshipType;
	NSString *escapedRelationshipName = [relationshipDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	NSString *escapedTableName = [_dk_mTableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	if(relationshipType == kDKRelationshipTypeOneToOne)
	{
		if(value)
			NSAssert([value isKindOfClass:[DKManagedObject class]], 
					 @"Non-database-object of type %@ given.", NSStringFromClass([value class]));
		
		DKManagedObject *databaseObject = (DKManagedObject *)value;
		
		
		//
		//	If we've been given a value we update the relationship with the unique identifier
		//	of the passed in database object.
		//
		//	If we're given nil and the relationship allows NULL values, we update the relationship with NULL.
		//
		NSString *updateQueryString = nil;
		NSString *inverseRelationshipUpdateQueryString = nil;
		if(value)
		{
			//
			//	One-to-one relationships are the simplest of relationships. They are represented in
			//	the database by a column of type BIGINT. The value of this column is the (database)
			//	unique identifier of the database value of the column.
			//
			updateQueryString = dk_string_from_format(
				dk_stringify_sql(
					UPDATE %@ SET '%@' = %lld WHERE _dk_uniqueIdentifier=%lld
				),
				escapedTableName, escapedRelationshipName, databaseObject.uniqueIdentifier, _dk_mUniqueIdentifier
			);
			
			
			//
			//	If this relationship has an inverse, we also need to update that.
			//	Bad shit will happen if we don't, afterall.
			//
			DKRelationshipDescription *inverseRelationship = relationshipDescription.inverseRelationship;
			if(inverseRelationship)
			{
				NSString *escapedInverseTableName = [databaseObject.tableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
				NSString *escapedInverseColumnName = [inverseRelationship.name stringByEscapingStringForLiteralUseInSQLQueries];
				inverseRelationshipUpdateQueryString = dk_string_from_format(
					dk_stringify_sql(
						UPDATE %@ SET '%@' = %lld WHERE _dk_uniqueIdentifier=%lld
					),
					escapedInverseTableName, escapedInverseColumnName, _dk_mUniqueIdentifier, databaseObject.uniqueIdentifier
				);
			}
		}
		else
		{
			//
			//	The update query is simple enough. Really. Its the same as the one above
			//	only it sets the relationship to NULL instead of a unique identifier.
			//
			updateQueryString = dk_string_from_format(
				dk_stringify_sql(
					UPDATE %@ SET '%@' = NULL WHERE _dk_uniqueIdentifier=%lld
				),
				escapedTableName, escapedRelationshipName, _dk_mUniqueIdentifier
			);
			
			
			//
			//	If this relationship has an inverse, we also need to update that.
			//	Bad shit will happen if we don't, afterall.
			//
			DKRelationshipDescription *inverseRelationship = relationshipDescription.inverseRelationship;
			if(inverseRelationship)
			{
				//
				//	Fetch the existing value for the relationship. If one exists
				//	we need to set its column that tracks us to NULL.
				//
				DKManagedObject *existingValue = [self valueForRelationship:relationshipDescription];
				if(existingValue)
				{
					NSString *escapedInverseTableName = [existingValue.tableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
					NSString *escapedInverseColumnName = [inverseRelationship.name stringByEscapingStringForLiteralUseInSQLQueries];
					
					inverseRelationshipUpdateQueryString = dk_string_from_format(
						dk_stringify_sql(
							UPDATE %@ SET '%@' = NULL WHERE _dk_uniqueIdentifier=%lld
						),
						escapedInverseTableName, escapedInverseColumnName, existingValue.uniqueIdentifier
					);
				}
			}
		}
		
		//
		//	Its time to update the relationship column. If this doesn't work the world is going to end.
		//
		NSAssert([_dk_mDatabase executeSQLQuery:updateQueryString error:&error],
				 @"Could not update relationship on object %@ with %@. Got error %@.", self, databaseObject, error);
		
		
		//
		//	We only run the inverse relationship update query if there's actually
		//	an inverse relationship to update.
		//
		if(inverseRelationshipUpdateQueryString)
			NSAssert([_dk_mDatabase executeSQLQuery:inverseRelationshipUpdateQueryString error:&error],
					 @"Could not update inverse relationship. Got error %@.", error);
	}
}

- (id)valueForRelationship:(DKRelationshipDescription *)relationshipDescription
{
	NSParameterAssert(relationshipDescription);
	
	NSError *error = nil;
	DKRelationshipType relationshipType = relationshipDescription.relationshipType;
	NSString *escapedRelationshipName = [relationshipDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	NSString *escapedTableName = [_dk_mTableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	if(relationshipType == kDKRelationshipTypeOneToOne)
	{
		//
		//	Look up the unique identifier of the value associated with this relationship.
		//
		NSString *selectQueryString = dk_string_from_format(
			dk_stringify_sql(
				SELECT %@ FROM %@ WHERE _dk_uniqueIdentifier=%lld
			),
			escapedRelationshipName, escapedTableName, _dk_mUniqueIdentifier
		);
		
		
		DKCompiledSQLQuery *selectQuery = [_dk_mDatabase compileSQLQuery:selectQueryString error:&error];
		NSAssert((selectQuery != nil), 
				 @"Could not select one-to-one relationship identifier. Got error %@.", error);
		
		
		if([selectQuery nextRow])
		{
			//
			//	If the resultant unique identifier is 0, it is assumed this means NULL in the database.
			//
			int64_t relationshipResultUniqueIdentifier = [selectQuery longLongForColumnAtIndex:0];
			if(relationshipResultUniqueIdentifier == 0)
				return nil;
			
			return [_dk_mDatabase databaseObjectInTable:relationshipDescription.targetTable 
								   withUniqueIdentifier:relationshipResultUniqueIdentifier];
		}
	}
	
	return nil;
}

#pragma mark -

- (void)setValue:(id)value forColumnNamed:(NSString *)key
{
	NSParameterAssert(key);
	
	//
	//	We look up the property associated with key in our table. If we can't find one
	//	then key isn't a column in the table this database object represents.
	//
	DKPropertyDescription *property = [_dk_mTableDescription propertyWithName:key];
	NSAssert((property != nil), @"No property by name %@ exists in the table %@.", key, _dk_mTableDescription.name);
	
	if([property isKindOfClass:[DKAttributeDescription class]])
	{
		DKAttributeDescription *attributeDescription = (DKAttributeDescription *)property;
		[self setValue:value forAttribute:attributeDescription];
		
		//
		//	Update the cache. This allows for faster access times.
		//
		if(value)
			[self cacheValue:value forKey:key];
		else
			[self removeCacheForKey:key];
	}
	else if([property isKindOfClass:[DKRelationshipDescription class]])
	{
		DKRelationshipDescription *relationshipDescription = (DKRelationshipDescription *)property;
		[self setValue:value forRelationship:relationshipDescription];
	}
}

- (id)valueForColumnNamed:(NSString *)key
{
	NSParameterAssert(key);
	
	//
	//	We first attempt to find a cached value for key. This will
	//	potentially save us quite a bit of time, especially if there
	//	are a lot of pending operations in the transaction queue.
	//
	id cachedValue = [self cachedValueForKey:key];
	if(cachedValue)
		return cachedValue;
	
	
	//
	//	We look up the property associated with key in our table. If we can't find one
	//	then key isn't a column in the table this database object represents.
	//
	DKPropertyDescription *property = [_dk_mTableDescription propertyWithName:key];
	NSAssert((property != nil), @"No property by name %@ exists in the table %@.", key, _dk_mTableDescription.name);
	
	if([property isKindOfClass:[DKAttributeDescription class]])
	{
		DKAttributeDescription *attributeDescription = (DKAttributeDescription *)property;
		
		id result = [self valueForAttribute:attributeDescription];
		
		//
		//	Update the cache. This allows for faster access times.
		//
		if(result)
			[self cacheValue:result forKey:key];
		else
			[self removeCacheForKey:key];
		
		return result;
	}
	else if([property isKindOfClass:[DKRelationshipDescription class]])
	{
		DKRelationshipDescription *relationshipDescription = (DKRelationshipDescription *)property;
		return [self valueForRelationship:relationshipDescription];
	}
	
	return nil;
}

#pragma mark -
#pragma mark Database Notifications

- (void)awakeFromInsertion
{
	//Do nothing.
}

- (void)awakeFromFetch
{
	//Do nothing.
}

#pragma mark -

- (void)prepareForDeletion
{
	NSError *error = nil;
	
	for (DKPropertyDescription *property in _dk_mTableDescription.properties)
	{
		if(![property isKindOfClass:[DKRelationshipDescription class]])
			continue;
		
		//
		//	Destroy any remnants of this values relationships. We don't want
		//	the database to become corrupted with stale references.
		//
		DKRelationshipDescription *relationship = (DKRelationshipDescription *)property;
		DKRelationshipDescription *inverseRelationship = relationship.inverseRelationship;
		if(inverseRelationship)
		{
			DKManagedObject *existingValue = [self valueForRelationship:relationship];
			if(existingValue)
			{
				DKRelationshipDeleteAction deleteAction = relationship.deleteAction;
				if(deleteAction == kDKRelationshipDeleteActionActionNullify)
				{
					NSString *escapedInverseTableName = [existingValue.tableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
					NSString *escapedInverseColumnName = [inverseRelationship.name stringByEscapingStringForLiteralUseInSQLQueries];
					
					NSString *inverseRelationshipUpdateQueryString = dk_string_from_format(
						dk_stringify_sql(
							UPDATE %@ SET '%@' = NULL WHERE _dk_uniqueIdentifier=%lld
						),
						escapedInverseTableName, escapedInverseColumnName, existingValue.uniqueIdentifier
					);
					NSLog(@"inverseRelationshipUpdateQueryString = %@", inverseRelationshipUpdateQueryString);
					
					NSAssert([_dk_mDatabase executeSQLQuery:inverseRelationshipUpdateQueryString error:&error],
							 @"Could not nullify relationship. Got error %@.", error);
				}
				else if(deleteAction == kDKRelationshipDeleteActionActionCascade)
				{
					/* TODO: Implement cascade deletions */
				}
			}
		}
	}
}

#pragma mark -
#pragma mark Overrides

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	if([_dk_mTableDescription propertyWithName:key])
		[self setValue:value forColumnNamed:key];
	else
		[super setValue:value forUndefinedKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key
{
	if([_dk_mTableDescription propertyWithName:key])
		return [self valueForColumnNamed:key];
	
	return [super valueForUndefinedKey:key];
}

#pragma mark -

- (NSString *)description
{
	/* <DKManagedObject:0x00000000 ([promise, ]UID: 0, table: Test, key: value, ...)> */
	NSMutableString *description = [NSMutableString stringWithFormat:@"<%@:%p (%@UID: %lld, table: %@", [self className], self, ([_dk_mCachedValues count] == 0)? @"promise, " : @"", _dk_mUniqueIdentifier, _dk_mTableDescription.name];
	
	[_dk_mCachedValues enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		[description appendFormat:@", %@: %@", key, value];
	}];
	[description appendString:@")>"];
	
	return description;
}

@end
