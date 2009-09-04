//
//  DKTransaction.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKTransaction.h"
#import "DKDatabase.h"

@implementation DKTransaction

@synthesize database = mDatabase;

#pragma mark -

- (id)initWithDatabase:(DKDatabase *)database
{
	if((self = [super init]))
	{
		mDatabase = database;
		
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Transactions

- (void)transactionWithBlock:(void(^)(DKTransaction *))block
{
	block(self);
}

@end
