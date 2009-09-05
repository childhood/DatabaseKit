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

@end

#pragma mark -

@implementation DKPropertyDescription

@synthesize name = mName;

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

@synthesize type, isRequired, minimumValue, maximumValue, defaultValue;

- (void)dealloc
{
	self.minimumValue = nil;
	self.maximumValue = nil;
	self.defaultValue = nil;
	
	[super dealloc];
}

+ (DKAttributeDescription *)attributeWithName:(NSString *)name type:(DKAttributeType)type
{
	DKAttributeDescription *attribute = [[DKAttributeDescription new] autorelease];
	attribute.name = name;
	attribute.type = type;
	return attribute;
}

@end

@implementation DKRelationshipDescription

@synthesize destination, isOneToMany, deleteAction;

- (void)dealloc
{
	self.destination = nil;
	
	[super dealloc];
}

@end
