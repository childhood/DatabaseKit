//
//  DKFetchRequest.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKFetchRequest.h"

@implementation DKFetchRequest

@synthesize table;
@synthesize filterString;
@synthesize predicate;
@synthesize sortDescriptors;

#pragma mark -

- (void)dealloc
{
	self.table = nil;
	self.filterString = nil;
	self.predicate = nil;
	self.sortDescriptors = nil;
	
	[super dealloc];
}

+ (DKFetchRequest *)fetchRequestWithTable:(DKTableDescription *)table
{
	DKFetchRequest *request = [[DKFetchRequest new] autorelease];
	
	request.table = table;
	
	return request;
}

@end
