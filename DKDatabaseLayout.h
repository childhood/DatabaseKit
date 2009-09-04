//
//  DKDatabaseLayout.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/3/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

DK_EXTERN NSString *const kDKEntityNameKey;
DK_EXTERN NSString *const kDKEntityClassKey;
DK_EXTERN NSString *const kDKEntityAttributesKey;
DK_EXTERN NSString *const kDKEntityRelationshipsKey;

DK_EXTERN NSString *const kDKAttributeNameKey;
DK_EXTERN NSString *const kDKAttributeTypeKey;
DK_EXTERN NSString *const kDKAttributeRequiredKey;
DK_EXTERN NSString *const kDKAttributeMinimumValueKey;
DK_EXTERN NSString *const kDKAttributeMaximumValueKey;
DK_EXTERN NSString *const kDKAttributeDefaultValueKey;

DK_EXTERN NSString *const kDKRelationshipNameKey;
DK_EXTERN NSString *const kDKRelationshipDestinationKey;
DK_EXTERN NSString *const kDKRelationshipOneToManyKey;
DK_EXTERN NSString *const kDKRelationshipDeleteActionKey;

enum _DKDeleteActions {
	kDKDeleteActionNullify = 0,
	kDKDeleteActionCascade,
};

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
 @abstract	Get the entities described in the receiver's database layout.
 @result	An array of dictionaries that use the kDKEntity* keys.
 */
- (NSArray *)entities;

@end

#pragma mark -

/*!
 @class
 @abstract	This class uses XML files to describe database layouts for DatabaseKit.
 */
@interface DKDatabaseLayout : NSObject < DKDatabaseLayout >
{
@package
	NSString *mName;
	float mDatabaseVersion;
	NSArray *mEntities;
}
- (id)initWithDatabaseLayoutAtURL:(NSURL *)url error:(NSError **)error;
+ (DKDatabaseLayout *)databaseLayoutAtURL:(NSURL *)url error:(NSError **)error;
@end
