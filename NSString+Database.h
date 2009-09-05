//
//  NSString+Database.h
//  DatabaseKit
//
//  Created by Peter MacWhinnie on 9/5/09.
//  Copyright 2009 Roundabout Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (DKDatabase)

- (NSString *)stringByEscapingStringForDatabaseQuery;

@end
