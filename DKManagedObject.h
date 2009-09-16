//
//  DKManagedObject.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DKTableDescription, DKDatabase;

/*!
 @method
 @abstract		This class is used to represent objects in a database.
 @discussion	DKManagedObject does not have a designated initializer.
				Use one of the methods on DKDatabase to acquire an instance of DKManagedObject.
				
				It is important to note that the life cycle of managed objects is controlled by DKDatabase.
				When the value a managed object represents is no longer valid it will be automatically
				destroyed by the database. A notification will be sent before the final deallocation so any
				pointers to the managed object can be zeroed.
				
				It is safe to place DKManagedObject into collections.
 */
@interface DKManagedObject : NSObject
{
@package
	//
	//	We use the (fairly strange) _dk_m prefix for ivars in DKManagedObject
	//	because it is meant to be subclassed and we don't want to conflict
	//	with ivars in subclasses.
	//
	
	/* owner */		int64_t _dk_mUniqueIdentifier;
	/* strong */	DKTableDescription *_dk_mTableDescription;
	/* weak */		DKDatabase *_dk_mDatabase;
	/* owner */		NSMutableDictionary *_dk_mCachedValues;
	/* n/a */		NSInteger _dk_mExtraRetainCount;
}
#pragma mark Accessing/Mutating Columns

/*!
 @method
 @abstract	Set the value of a specified column.
 @param		value	The value to assign to a specified column. May be nil.
 @param		key		The name of the specified column in the receiver's table description. May not be nil.
 */
- (void)setValue:(id)value forColumnNamed:(NSString *)key;

/*!
 @method
 @abstract		Get the value of a specified column.
 @param			key		The name of the specified column in the receiver's table description. May not be nil.
 @discussion	No assumptions should be made about the amount of time this method takes to fetch the value.
				The receiver might have a local cache of the value for the specified key or it may need to
				fetch it from the database.
 */
- (id)valueForColumnNamed:(NSString *)key;

#pragma mark -
#pragma mark Database Notifications

/*!
 @method
 @abstract		Invoked by DatabaseKit when the receiver is first inserted into a DKDatabase.
 @discussion	You do not typically invoke this method yourself, it is called automatically by DKDatabase.
				
				Default implementation does nothing. It is not necessary to message super.
 */
- (void)awakeFromInsertion;

/*!
 @method
 @abstract		Invoked by DatabaseKit when the receiver is fetched from a DKDatabase.
 @discussion	You do not typically invoke this method yourself, it is called automatically by DKDatabase.
				
				Default implementation does nothing. It is not necessary to message super.
 */
- (void)awakeFromFetch;

#pragma mark -

/*!
 @method
 @abstract		Invoked by DatabaseKit when the receiver is about to be deleted from the database.
 @discussion	You do not typically invoke this method yourself, it is called automatically by DKDatabase.
				
				Subclasses _must_ invoke their superclass's implementation of this method. Relationships will
				not be properly cleaned up and this can lead to corruption of the database.
 */
- (void)prepareForDeletion;

#pragma mark -
#pragma mark Properties

/*!
 @property
 @abstract	The database that the managed object is owned by.
 */
@property (readonly) DKDatabase *database;

/*!
 @property
 @abstract	The table description that the managed object represents.
 */
@property (readonly) DKTableDescription *tableDescription;
@end
