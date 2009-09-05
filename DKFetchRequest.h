//
//  DKFetchRequest.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DKTableDescription;
@interface DKFetchRequest : NSObject
{
	DKTableDescription *table;
	NSString *filterString;
	NSPredicate *predicate;
	NSArray *sortDescriptors;
}
+ (DKFetchRequest *)fetchRequestWithTable:(DKTableDescription *)table;

@property (copy) DKTableDescription *table;

@property (copy) NSString *filterString;

@property (copy) NSPredicate *predicate;

@property (retain) NSArray *sortDescriptors;
@end
