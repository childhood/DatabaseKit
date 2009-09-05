//
//  NSString+Database.m
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/5/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import "NSString+Database.h"

@implementation NSString (DKDatabase)

- (NSString *)stringByEscapingStringForDatabaseQuery
{
	return [self stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
}

@end
