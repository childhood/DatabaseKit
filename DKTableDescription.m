//
//  DKTableDescription.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKTableDescription.h"

@implementation DKTableDescription
@synthesize name = mName;
@synthesize databaseObjectClass = mDatabaseObjectClass;
@synthesize properties = mProperties;

#pragma mark -

- (void)dealloc
{
	[mName release];
	mName = nil;
	
	[mProperties release];
	mProperties = nil;
	
	[super dealloc];
}

- (id)init
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithName:(NSString *)name databaseObjectClass:(Class)databaseObjectClass properties:(NSArray *)properties
{
	if((self = [super init]))
	{
		mName = [name copy];
		mDatabaseObjectClass = databaseObjectClass;
		mProperties = [[NSArray alloc] initWithArray:properties copyItems:NO];
		
		return self;
	}
	return nil;
}

- (DKPropertyDescription *)propertyWithName:(NSString *)name
{
	NSParameterAssert(name);
	
	NSUInteger indexOfProperty = [mProperties indexOfObjectPassingTest:^(id property, NSUInteger index, BOOL *stop) {
		return [[property name] isEqualToString:name];
	}];
	
	if(indexOfProperty != NSNotFound)
		return [mProperties objectAtIndex:indexOfProperty];
	
	return nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:%p (name: %@, databaseObjectClass: %@, properties: [%@])>", [self className], self, mName, NSStringFromClass(mDatabaseObjectClass), [mProperties componentsJoinedByString:@", "]];
}

@end

#pragma mark -

@implementation DKPropertyDescription

@synthesize name = mName;
@synthesize isRequired = mIsRequired;

- (void)dealloc
{
	[mName release];
	mName = nil;
	
	[super dealloc];
}

@end

#pragma mark -

NSString *DKAttributeTypeToSQLiteType(DKAttributeType attributeType)
{
	switch (attributeType)
	{
		case DKAttributeTypeString:
			return @"TEXT";
			
		case DKAttributeTypeDate:
			return @"DATETIME";
			
		case DKAttributeTypeInt8:
			return @"TINYINT";
			
		case DKAttributeTypeInt16:
			return @"SMALLINT";
			
		case DKAttributeTypeInt32:
			return @"INT";
			
		case DKAttributeTypeInt64:
			return @"BIGINT";
			
		case DKAttributeTypeFloat:
			return @"FLOAT";
			
		case DKAttributeTypeData:
		case DKAttributeTypeObject:
			return @"BLOB";
			
		default:
			break;
	}
	
	return nil;
}

@implementation DKAttributeDescription

@synthesize type, minimumValue, maximumValue, defaultValue;

- (void)dealloc
{
	self.minimumValue = nil;
	self.maximumValue = nil;
	self.defaultValue = nil;
	
	[super dealloc];
}

+ (DKAttributeDescription *)attributeWithName:(NSString *)name type:(DKAttributeType)type
{
	NSParameterAssert(name);
	
	DKAttributeDescription *attribute = [[self new] autorelease];
	
	attribute.name = name;
	attribute.type = type;
	
	return attribute;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:%p (name: %@, type: %@)>", [self className], self, mName, DKAttributeTypeToSQLiteType(type)];
}

@end

@implementation DKRelationshipDescription

@synthesize targetTable, inverseRelationship, relationshipType, deleteAction;

- (void)dealloc
{
	self.targetTable = nil;
	self.inverseRelationship = nil;
	
	[super dealloc];
}

+ (DKRelationshipDescription *)relationshipWithTargetTable:(DKTableDescription *)targetTable inverseRelationship:(DKRelationshipDescription *)inverseRelationship type:(DKRelationshipType)type
{
	NSParameterAssert(targetTable);
	
	DKRelationshipDescription *relationship = [[self new] autorelease];
	
	relationship.targetTable = targetTable;
	relationship.inverseRelationship = inverseRelationship;
	relationship.relationshipType = type;
	
	return relationship;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:%p (name: %@, from %@ to %@)>", [self className], self, mName, targetTable.name, inverseRelationship.targetTable.name];
}

@end
