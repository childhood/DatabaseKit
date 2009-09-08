//
//  NSString+Database.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/5/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSString (DatabaseKit)

/*!
 @method
 @abstract	Cleanse the receiver of any characters that might interfere with its use as a literal in an SQL query.
 */
- (NSString *)stringByEscapingStringForLiteralUseInSQLQueries;

@end
