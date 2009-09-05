//
//  DKDatabaseLayout.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
 @protocol
 @abstract	Objects that implement this protocol can be used to describe database layouts in DatabaseKit.
 */
@protocol DKDatabaseLayout < NSObject >

/*!
 @method
 @abstract	Get the name of the receiver's database layout.
 */
- (NSString *)databaseName;

/*!
 @method
 @abstract	Get the version of the receiver's database layout.
 */
- (float)databaseVersion;


/*!
 @method
 @abstract	Get the tables described in the receiver's database layout.
 @result	An array of DKTableDescription objects.
 */
- (NSArray *)tables;

@end

#pragma mark -

@interface DKDatabaseLayout : NSObject < DKDatabaseLayout >
{
@package
	NSString *mName;
	float mDatabaseVersion;
	NSArray *mTables;
}
/*!
 @method
 @abstract	Initialize a database layout with a name, version, and an array of table description objects.
 @param		name	The name of the database layout. May not be nil.
 @param		version	The version of the database layout.
 @param		tables	An array of DKTableDescription objects. May not be nil.
 @result	A fully initialied DKDatabaseLayout if no errors occur.
 */
- (id)initWithName:(NSString *)name version:(float)version tables:(NSArray *)tables;
@end
