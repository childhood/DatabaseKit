//
//  DKFetchRequest.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKFetchRequest.h"

@implementation DKFetchRequest

#pragma mark Destruction

- (void)dealloc
{
	self.table = nil;
	self.filterString = nil;
	self.predicate = nil;
	self.sortDescriptors = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Construction

+ (DKFetchRequest *)fetchRequestWithTable:(DKTableDescription *)table
{
	DKFetchRequest *request = [[DKFetchRequest new] autorelease];
	
	request.table = table;
	
	return request;
}

- (id)init
{
	if((self = [super init]))
	{
		returnsObjectsAsPromises = YES;
		
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Properties

@synthesize table;
@synthesize filterString;
@synthesize predicate;
@synthesize sortDescriptors;
@synthesize returnsObjectsAsPromises;

@end
