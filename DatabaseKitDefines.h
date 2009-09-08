/*
 *  DatabaseKitDefines.h
 *  DatabaseKit
 *
 *  Created by Peter MacWhinnie on 9/3/09.
 *  Copyright 2009 Roundabout Software. All rights reserved.
 *
 */

#ifndef DatabaseKitDefines_h
#define DatabaseKitDefines_h 1

#pragma mark Symbol Defines

#if !defined(DK_EXTERN)
#	if __cplusplus
#		define DK_EXTERN	extern "C"
#	else
#		define DK_EXTERN	extern
#	endif /* __cplusplus */
#endif /* !defined(DK_EXTERN) */

#if !defined(DK_INLINE)
#define DK_INLINE	__attribute__((always_inline)) static inline
#endif /* !defined(DK_INLINE) */

#pragma mark Errors

DK_EXTERN NSString *const DKGeneralErrorDomain;
DK_EXTERN NSString *const DKInitializationErrorDomain;
DK_EXTERN NSString *const DKEvaluationErrorDomain;

/*!
 @function
 @abstract	Create a new error with a domain, status code, user data, localization key.
 @param		domain		The domain of the error. May not be nil.
 @param		code		The code of the error.
 @param		userInfo	The userInfo of the error. May be nil.
 @param		key			The key of the string to use for formatting from the Errors.strings localization table. May not be nil.
 @result	A new autoreleased instance of NSError configured with the parameters passed in.
 */
DK_EXTERN NSError *DKLocalizedError(NSString *domain, NSInteger code, NSDictionary *userInfo, NSString *key, ...);

/*!
 @typedef
 @abstract	This type is used to make the use of return values from SQLite functions more clear.
 */
typedef int SQLiteStatus;

#endif /* DatabaseKitDefines_h */
