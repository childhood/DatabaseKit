//
//  DKDatabaseLayout.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "DKDatabaseLayout.h"

@implementation DKDatabaseLayout

- (void)dealloc
{
	[mName release];
	mName = nil;
	
	[mTables release];
	mTables = nil;
	
	[super dealloc];
}

- (id)initWithName:(NSString *)name version:(float)version tables:(NSArray *)tables
{
	if((self = [super init]))
	{
		mName = [name copy];
		mDatabaseVersion = version;
		mTables = [[NSArray alloc] initWithArray:tables copyItems:NO];
		
		return self;
	}
	return nil;
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

- (NSArray *)tables
{
	return mTables;
}

@end
