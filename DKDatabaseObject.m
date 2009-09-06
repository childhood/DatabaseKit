//
//  DKDatabaseObject.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKDatabaseObject.h"
#import "DKDatabaseObjectPrivate.h"

#import "DKDatabase.h"
#import "DKDatabasePrivate.h"
#import "DKTableDescription.h"
#import "DKTransaction.h"
#import <sqlite3.h>

@implementation DKDatabaseObject

- (void)dealloc
{
	if(mCachedValues)
	{
		[mCachedValues release];
		mCachedValues = nil;
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
		mUniqueIdentifier = uniqueIdentifier;
		mTableDescription = table;
		mDatabase = database;
		
		mCachedValues = [NSMutableDictionary new];
		
		return self;
	}
	return nil;
}

- (id)initWithTable:(DKTableDescription *)table insertIntoDatabase:(DKDatabase *)database
{
	NSParameterAssert(table);
	NSParameterAssert(database);
	
	return [database insertNewObjectIntoTable:table];
}

#pragma mark -
#pragma mark Cache Management

- (void)cacheValue:(id)value forKey:(NSString *)key
{
	@synchronized(self)
	{
		[mCachedValues setObject:value forKey:key];
	}
}

- (id)cachedValueForKey:(NSString *)key
{
	@synchronized(self)
	{
		return [mCachedValues objectForKey:key];
	}
}

- (void)removeCacheForKey:(NSString *)key
{
	@synchronized(self)
	{
		[mCachedValues removeObjectForKey:key];
	}
}

- (void)invalidateCache
{
	@synchronized(self)
	{
		[mCachedValues removeAllObjects];
	}
}

#pragma mark -
#pragma mark Database Accessor/Mutators

- (void)setDatabaseValue:(id)value forKey:(NSString *)key
{
	NSParameterAssert(key);
	
	DKPropertyDescription *property = [mTableDescription propertyWithName:key];
	NSAssert((property != nil), @"No property by name %@ exists in the table %@.", key, mTableDescription.name);
	
	NSAssert([property isKindOfClass:[DKAttributeDescription class]], @"Unsupported attribute type %@.", property);
	
	[mDatabase transaction:^(DKTransaction *transaction) {
		NSError *error = nil;
		
		DKAttributeDescription *attributeDescription = (DKAttributeDescription *)property;
		
		NSString *statement = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ? WHERE _dk_uniqueIdentifier=%lld", mTableDescription.name, attributeDescription.name, mUniqueIdentifier];
		NSAssert([transaction compileSQLStatement:statement error:&error], 
				 @"Could not prepare statement %@. Got error %@.", error);
		
		if(value)
		{
			switch (attributeDescription.type)
			{
				case DKAttributeTypeString:
				{
					[transaction setString:value forColumnAtIndex:1];
					
					break;
				}
				case DKAttributeTypeDate:
				{
					[transaction setDate:value forColumnAtIndex:1];
					
					break;
				}
				case DKAttributeTypeInt8:
				case DKAttributeTypeInt16:
				case DKAttributeTypeInt32:
				{
					[transaction setInt:[value intValue] forColumnAtIndex:1];
					
					break;
				}
				case DKAttributeTypeInt64:
				{
					[transaction setLongLong:[value longLongValue] forColumnAtIndex:1];
					
					break;
				}
				case DKAttributeTypeFloat:
				{
					[transaction setDouble:[value doubleValue] forColumnAtIndex:1];
					
					break;
				}
				case DKAttributeTypeData:
				{
					[transaction setData:value forColumnAtIndex:1];
					
					break;
				}
				case DKAttributeTypeObject:
				{
					[transaction setObject:value forColumnAtIndex:1];
					
					break;
				}
				default:
				{
					[transaction setNullForColumnAtIndex:1];
					
					break;
				}
			}
		}
		else
		{
			[transaction setNullForColumnAtIndex:1];
		}
		
		NSAssert(([transaction evaluateStatement] == SQLITE_OK), 
				 @"Could not update %@ to %@. Error %@.", key, value, [transaction lastError]);
	}];
	
	if(value)
		[self cacheValue:value forKey:key];
	else
		[self removeCacheForKey:key];
}

- (id)databaseValueForKey:(NSString *)key
{
	NSParameterAssert(key);
	
	id cachedValue = [self cachedValueForKey:key];
	if(cachedValue)
		return cachedValue;
	
	DKPropertyDescription *property = [mTableDescription propertyWithName:key];
	NSAssert((property != nil), @"No property by name %@ exists in the table %@.", key, mTableDescription.name);
	
	NSAssert([property isKindOfClass:[DKAttributeDescription class]], @"Unsupported attribute type %@.", property);
	
	__block id result = nil;
	[mDatabase transaction:^(DKTransaction *transaction) {
		NSError *error = nil;
		
		NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE(_dk_uniqueIdentifier=%lld)", key, mTableDescription.name, mUniqueIdentifier];
		NSAssert([transaction compileSQLStatement:statement error:&error], 
				 @"Could not look up value for %@. Error %@.", key, error);
		
		NSAssert(([transaction evaluateStatement] == SQLITE_ROW), 
				 @"Could not step into query %@. Got error %@.", statement, [transaction lastError]);
		
		DKAttributeDescription *attributeDescription = (DKAttributeDescription *)property;
		switch (attributeDescription.type)
		{
			case DKAttributeTypeString:
			{
				result = [transaction stringForColumnAtIndex:0];
				
				break;
			}
			case DKAttributeTypeDate:
			{
				result = [transaction dateForColumnAtIndex:0];
				
				break;
			}
			case DKAttributeTypeInt8:
			case DKAttributeTypeInt16:
			case DKAttributeTypeInt32:
			{
				result = [NSNumber numberWithInt:[transaction intForColumnAtIndex:0]];
				
				break;
			}
			case DKAttributeTypeInt64:
			{
				result = [NSNumber numberWithLongLong:[transaction longLongForColumnAtIndex:0]];
				
				break;
			}
			case DKAttributeTypeFloat:
			{
				result = [NSNumber numberWithDouble:[transaction doubleForColumnAtIndex:0]];
				
				break;
			}
			case DKAttributeTypeData:
			{
				result = [transaction dataForColumnAtIndex:0];
				
				break;
			}
			case DKAttributeTypeObject:
			{
				result = [transaction objectForColumnAtIndex:0];
				
				break;
			}
			default:
				break;
		}
	}];
	
	return result;
}

#pragma mark -
#pragma mark Callbacks

- (void)awakeFromInsertion
{
	//Do nothing.
}

- (void)awakeFromFetch
{
	
}

#pragma mark -
#pragma mark Overrides

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	if([mTableDescription propertyWithName:key] == nil)
		return [super setValue:value forUndefinedKey:key];
	
	[self setDatabaseValue:value forKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key
{
	if([mTableDescription propertyWithName:key] == nil)
		return [super valueForUndefinedKey:key];
	
	return [self databaseValueForKey:key];
}

#pragma mark -

- (NSString *)description
{
	if([mCachedValues count] == 0)
		return [NSString stringWithFormat:@"<%@:%p (promise, UID: %lld, table: %@)>", [self className], self, mUniqueIdentifier, mTableDescription.name];
	
	return [NSString stringWithFormat:@"<%@:%p (UID: %lld, table: %@) %@>", [self className], self, mUniqueIdentifier, mTableDescription.name, [mCachedValues description]];
}

@end
