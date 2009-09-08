//
//  DKDatabaseTests.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/7/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKDatabaseTests.h"
#import <DatabaseKit/DatabaseKit.h>

@implementation DKDatabaseTests

- (void)setUp
{
	mTestDatabaseURL = [[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"DatabaseKitTest.sqlite3"]] retain];
}

- (void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtURL:mTestDatabaseURL error:nil];
	[mTestDatabaseURL release];
}

@end
