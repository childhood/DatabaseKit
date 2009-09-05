/*
 *  DKTransactionPrivate.h
 *  DatabaseKit
 *
 *  Created by Peter MacWhinnie on 9/5/09.
 *  Copyright 2009 Roundabout Software. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "DKTransaction.h"

//! @abstract	The private interface continuation of DKTransaction.
@interface DKTransaction () //Continuation

/*!
 @method
 @abstract		Initialize a transaction with a database object.
 @param			database	The database the transaction is to operate through. May not be nil.
 @discussion	DKTransaction only keeps a weak reference to database. It is the database's responsibility
				terminate any pending transactions and destroy if it is released.
 */
- (id)initWithDatabase:(DKDatabase *)database;

@end

