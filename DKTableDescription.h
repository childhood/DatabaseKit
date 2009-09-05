//
//  DKTableDescription.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/4/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DKPropertyDescription;

/*!
 @class
 @abstract	This class is used to describe tables in a DKDatabase.
 */
@interface DKTableDescription : NSObject
{
	NSString *mName;
	Class mDatabaseObjectClass;
	NSArray *mProperties;
}
/*!
 @method
 @abstract	Initialize a table description with a name, database object class, and an array of DK*Description objects.
 */
- (id)initWithName:(NSString *)name databaseObjectClass:(Class)databaseObjectClass properties:(NSArray *)properties;

/*!
 @property
 @abstract	The table's name.
 */
@property (readonly) NSString *name;

/*!
 @property
 @abstract	The database object class used to represent the table at runtime.
 */
@property (readonly) Class databaseObjectClass;

/*!
 @property
 @abstract	An array of DKPropertyDescription objects describing the table.
 */
@property (readonly) NSArray *properties;

/*!
 @method
 @abstract	Look up a property by a specified name in the receiver's properties.
 @param		name	The name of the property to look up. May not be nil.
 @result	The first property found with `name`.
 */
- (DKPropertyDescription *)propertyWithName:(NSString *)name;
@end

#pragma mark -

/*!
 @method
 @abstract	This class is used to define properties in a table description.
 */
@interface DKPropertyDescription : NSObject
{
	NSString *mName;
}

/*!
 @property
 @abstract	The name of the property.
 */
@property (copy) NSString *name;

@end

#pragma mark -

typedef enum DKAttributeType {
	DKAttributeTypeString = 0,
	DKAttributeTypeDate,
	DKAttributeTypeInt8,
	DKAttributeTypeInt16,
	DKAttributeTypeInt32,
	DKAttributeTypeInt64,
	DKAttributeTypeFloat,
	DKAttributeTypeData,
	DKAttributeTypeObject,
	
	//DKAttributeTypeInteger behaves like NSInteger.
#if __LP64__
	DKAttributeTypeInteger = DKAttributeTypeInt64,
#else
	DKAttributeTypeInteger = DKAttributeTypeInt32,
#endif /* __LP64__ */
} DKAttributeType;

/*!
 @function
 @abstract	Convert a DKAttributeType value to an SQLite type.
 */
DK_EXTERN NSString *DKAttributeTypeToSQLiteType(DKAttributeType attributeType);

@interface DKAttributeDescription : DKPropertyDescription
{
@package
	DKAttributeType type;
	BOOL isRequired;
	NSNumber *minimumValue;
	NSNumber *maximumValue;
	id defaultValue;
}
+ (DKAttributeDescription *)attributeWithName:(NSString *)name type:(DKAttributeType)type;

@property DKAttributeType type;
@property BOOL isRequired;
@property (retain) NSNumber *minimumValue;
@property (retain) NSNumber *maximumValue;
@property (retain) id defaultValue;
@end

#pragma mark -

typedef enum DKDeleteAction {
	kDKDeleteActionNullify = 0,
	kDKDeleteActionCascade,
} DKDeleteAction;

@interface DKRelationshipDescription : DKPropertyDescription
{
@package
	NSString *destination;
	BOOL isOneToMany;
	DKDeleteAction deleteAction;
}
@property (copy) NSString *destination;
@property BOOL isOneToMany;
@property DKDeleteAction deleteAction;
@end

