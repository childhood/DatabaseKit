/*
 *  DKDatabasePrivate.h
 *  DatabaseKit
 *
 *  Created by Peter MacWhinnie on 9/5/09.
 *  Copyright 2009 Roundabout Software. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "DKDatabase.h"

//! @abstract	The DKDatabase private continuation.
@interface DKDatabase () //Continuation

/*!
 @property
 @abstract		The SQLite handle of the database.
 @discussion	Direct interaction with this value is discouraged. Use a transaction whenever possible.
 */
@property (readonly) sqlite3 *sqliteHandle;

@end
