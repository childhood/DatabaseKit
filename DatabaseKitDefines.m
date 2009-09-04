/*
 *  DatabaseKitDefines.m
 *  DatabaseKit
 *
 *  Created by Peter MacWhinnie on 9/3/09.
 *  Copyright 2009 Roundabout Software. All rights reserved.
 *
 */

#import "DatabaseKitDefines.h"
#import <stdarg.h>

NSString *const DKGeneralErrorDomain = @"DKGeneralErrorDomain";

NSError *DKLocalizedError(NSString *domain, NSInteger code, NSDictionary *userInfo, NSString *key, ...)
{
	NSCParameterAssert(domain);
	NSCParameterAssert(key);
	
	//
	//	If an existing userInfo has been passed in, we create a mutable copy
	//	of it. If it doesn't exist we make an empty mutable dictionary.
	//	We set the NSLocalizedDescriptionKey of this dictionary below.
	//
	NSMutableDictionary *errorUserInfo = nil;
	if(userInfo)
		errorUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
	else
		errorUserInfo = [NSMutableDictionary dictionary];
	
	//
	//	Resolve the error in the Errors.strings localization table.
	//	We assume that the value returned is a format string and as
	//	such we pass it into NSString along with the va_args given
	//	to this function.
	//
	va_list formatArguments;
	va_start(formatArguments, key);
	
	NSString *rawLocalizedDescription = [[NSBundle bundleWithIdentifier:@"com.roundabout.DatabaseKit"] localizedStringForKey:key value:key table:@"Errors"];
	NSString *localizedDescription = [[NSString alloc] initWithFormat:rawLocalizedDescription arguments:formatArguments];
	
	va_end(formatArguments);
	
	
	[errorUserInfo setValue:localizedDescription forKey:NSLocalizedDescriptionKey];
	[localizedDescription release];
	
	
	return [NSError errorWithDomain:domain code:code userInfo:errorUserInfo];
}
