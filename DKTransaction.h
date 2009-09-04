//
//  DKTransaction.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DKDatabase;
@interface DKTransaction : NSObject
{
@package
	DKDatabase *mDatabase;
}
- (id)initWithDatabase:(DKDatabase *)database;

- (void)transactionWithBlock:(void(^)(DKTransaction *))block;

@property (readonly) DKDatabase *database;
@end
