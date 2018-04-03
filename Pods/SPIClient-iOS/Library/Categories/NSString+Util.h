//
//  NSString+Util.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Util)

/**
 *  NSString with leading/trailing whitespace removed
 */
@property (nonatomic, readonly, nonnull) NSString *trim;

@property (nonatomic, readonly, nonnull) NSDate *toDate;

@end
