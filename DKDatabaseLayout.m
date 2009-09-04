//
//  DKDatabaseLayout.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKDatabaseLayout.h"

NSString *const kDKEntityNameKey = @"kDKEntityNameKey";
NSString *const kDKEntityClassKey = @"kDKEntityClassKey";
NSString *const kDKEntityAttributesKey = @"kDKEntityAttributesKey";
NSString *const kDKEntityRelationshipsKey = @"kDKEntityRelationshipsKey";

NSString *const kDKAttributeNameKey = @"kDKAttributeNameKey";
NSString *const kDKAttributeTypeKey = @"kDKAttributeTypeKey";
NSString *const kDKAttributeRequiredKey = @"kDKAttributeRequiredKey";
NSString *const kDKAttributeMinimumValueKey = @"kDKAttributeMinimumValueKey";
NSString *const kDKAttributeMaximumValueKey = @"kDKAttributeMaximumValueKey";
NSString *const kDKAttributeDefaultValueKey = @"kDKAttributeDefaultValueKey";

NSString *const kDKRelationshipNameKey = @"kDKRelationshipNameKey";
NSString *const kDKRelationshipDestinationKey = @"kDKRelationshipDestinationKey";
NSString *const kDKRelationshipOneToManyKey = @"kDKRelationshipOneToManyKey";
NSString *const kDKRelationshipDeleteActionKey = @"kDKRelationshipDeleteActionKey";

@implementation DKDatabaseLayout

- (id)initWithDatabaseLayoutAtURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(url);
	if((self = [super init]))
	{
		NSXMLDocument *layoutDocument = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:error];
		if(!layoutDocument)
		{
			[self release];
			return nil;
		}
		
		[layoutDocument release];
		
		return self;
	}
	return nil;
}

+ (DKDatabaseLayout *)databaseLayoutAtURL:(NSURL *)url error:(NSError **)error
{
	return [[[self alloc] initWithDatabaseLayoutAtURL:url error:error] autorelease];
}

#pragma mark -

- (NSString *)databaseName
{
	return mName;
}

- (float)databaseVersion
{
	return mDatabaseVersion;
}

- (NSArray *)entities
{
	return mEntities;
}

@end
