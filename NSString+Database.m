//
//  NSString+Database.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/5/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "NSString+Database.h"

@implementation NSString (DatabaseKit)

- (NSString *)stringByEscapingStringForLiteralUseInSQLQueries
{
	NSMutableString *cleansedString = [NSMutableString stringWithString:self];
	
	//
	//	We prepend Z_ to the ourselves in the event this string corresponds to an SQL keyword.
	//
	[cleansedString insertString:@"Z_" atIndex:0];
	
	//
	//	Replace whitespace, single quotes, and double quotes with an underscore.
	//	This is done to prevent potential SQL injection.
	//
	[cleansedString replaceOccurrencesOfString:@" " 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	[cleansedString replaceOccurrencesOfString:@"\t" 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	[cleansedString replaceOccurrencesOfString:@"\n" 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	[cleansedString replaceOccurrencesOfString:@"\r" 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	[cleansedString replaceOccurrencesOfString:@"'" 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	[cleansedString replaceOccurrencesOfString:@"(" 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	[cleansedString replaceOccurrencesOfString:@")" 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	[cleansedString replaceOccurrencesOfString:@"\"" 
									withString:@"_" 
									   options:0 
										 range:NSMakeRange(0, [cleansedString length])];
	
	return cleansedString;
}

@end
