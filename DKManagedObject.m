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
		
		return self;
	}
	return nil;
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
	//	If it doesn't, something has gone horribly awry and its time to shave your head.
	//
	NSAssert([selectQuery nextRow], 
			 @"Select query could not return any results for key %@. Got error %@.", attributeDescription.name, error);
	
	
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
	NSError *error = nil;
	DKRelationshipType relationshipType = relationshipDescription.relationshipType;
	NSString *escapedRelationshipName = [relationshipDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	NSString *escapedTableName = [_dk_mTableDescription.name stringByEscapingStringForLiteralUseInSQLQueries];
	
	if(relationshipType == kDKRelationshipTypeOneToOne)
	{
		NSAssert([value isKindOfClass:[DKManagedObject class]], 
				 @"Non-database-object of type %@ given.", NSStringFromClass([value class]));
		
		DKManagedObject *databaseObject = (DKManagedObject *)value;
		(void)databaseObject;
	}
}

- (id)valueForRelationship:(DKRelationshipDescription *)relationshipDescription
{
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
	//Do nothing.
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
