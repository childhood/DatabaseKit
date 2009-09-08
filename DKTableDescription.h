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

typedef enum _DKAttributeType {
	/*!
	 @enum		DKAttributeType
	 @abstract	This enum is used to describe the type of the value an attribute represents.
	 */
	
	/*!
	 @constant	DKAttributeTypeString
	 @abstract	The attribute represents a string.
	 */
	DKAttributeTypeString = 0,
	
	/*!
	 @constant	DKAttributeTypeDate
	 @abstract	The attribute represents a date.
	 */
	DKAttributeTypeDate,
	
	/*!
	 @constant	DKAttributeTypeInt8
	 @abstract	The attribute represents an 8 bit integer.
	 */
	DKAttributeTypeInt8,
	
	/*!
	 @constant	DKAttributeTypeInt16
	 @abstract	The attribute represents a 16 bit integer.
	 */
	DKAttributeTypeInt16,
	
	/*!
	 @constant	DKAttributeTypeInt32
	 @abstract	The attribute represents a 32 bit integer.
	 */
	DKAttributeTypeInt32,
	
	/*!
	 @constant	DKAttributeTypeInt64
	 @abstract	The attribute represents a 64 bit integer.
	 */
	DKAttributeTypeInt64,
	
	/*!
	 @constant	DKAttributeTypeFloat
	 @abstract	The attribute represents a float.
	 */
	DKAttributeTypeFloat,
	
	/*!
	 @constant	DKAttributeTypeData
	 @abstract	The attribute represents a data value.
	 */
	DKAttributeTypeData,
	
	/*!
	 @constant	DKAttributeTypeObject
	 @abstract	The attribute represents a object conforming to NSCoder.
	 */
	DKAttributeTypeObject,
	
	/*!
	 @constant	DKAttributeTypeInteger
	 @abstract	The attribute represents a 32 bit integer when compiled for x86 and a 64 bit integer when compiled for x86_64.
	 */
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

#pragma mark -

/*!
 @class
 @abstract	This class is used to represent attributes in DatabaseKit.
 */
@interface DKAttributeDescription : DKPropertyDescription
{
@package
	DKAttributeType type;
	BOOL isRequired;
	NSNumber *minimumValue;
	NSNumber *maximumValue;
	id defaultValue;
}
/*!
 @method
 @abstract	Create a new autoreleased attribute with a name and a type.
 @param		name	The name of the attribute. May not be nil.
 @param		type	The type of the attribute.
 @result	A new autoreleased attribute description.
 */
+ (DKAttributeDescription *)attributeWithName:(NSString *)name type:(DKAttributeType)type;

#pragma mark -

/*!
 @property
 @abstract	The type of the attribute.
 */
@property DKAttributeType type;

/*!
 @property
 @abstract	Whether or not this attribute requires a non-nil value.
 */
@property BOOL isRequired;

/*!
 @property
 @abstract		The minimum number-value of the attribute.
 @discussion	A maximum value can only be given to numbers.
 */
@property (retain) NSNumber *minimumValue;

/*!
 @property
 @abstract		The maximum number-value of the attribute.
 @discussion	A maximum value can only be given to numbers.
 */
@property (retain) NSNumber *maximumValue;

/*!
 @property
 @abstract		The default value of the property.
 @discussion	A default value can only be given to numbers and strings.
 */
@property (retain) id defaultValue;
@end

#pragma mark -

typedef enum _DKRelationshipType {
	kDKRelationshipTypeOneToOne = 0,
	kDKRelationshipTypeOneToMany,
	kDKRelationshipTypeManyToMany,
} DKRelationshipType;

typedef enum _DKRelationshipDeleteAction {
	kDKRelationshipDeleteActionActionNullify = 0,
	kDKRelationshipDeleteActionActionCascade,
} DKRelationshipDeleteAction;

#pragma mark -

@interface DKRelationshipDescription : DKPropertyDescription
{
@package
	NSString *destination;
	NSString *inverseRelationshipName;
	DKRelationshipType relationshipType;
	DKRelationshipDeleteAction deleteAction;
}
@property (copy) NSString *destination;
@property (copy) NSString *inverseRelationshipName;

@property DKRelationshipType relationshipType;
@property DKRelationshipDeleteAction deleteAction;
@end

