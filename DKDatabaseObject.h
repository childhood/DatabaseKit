//
//  DKDatabaseObject.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DKTableDescription, DKDatabase;

/*!
 @method
 @abstract	This class is used to represent objects in a database.
 */
@interface DKDatabaseObject : NSObject
{
@package
	/* owner */		int64_t mUniqueIdentifier;
	/* strong */	DKTableDescription *mTableDescription;
	/* weak */		DKDatabase *mDatabase;
	/* owner */		NSMutableDictionary *mCachedValues;
}
- (id)initWithTable:(DKTableDescription *)table insertIntoDatabase:(DKDatabase *)database;

- (void)setDatabaseValue:(id)value forKey:(NSString *)key;
- (id)databaseValueForKey:(NSString *)key;

- (void)awakeFromInsertion;
- (void)awakeFromFetch;
@end
