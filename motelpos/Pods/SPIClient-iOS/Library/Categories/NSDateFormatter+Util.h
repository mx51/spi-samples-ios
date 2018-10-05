//
//  NSDateFormatter+Util.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDateFormatter (Util)

/**
 * Formats date time string in format: yyyy-MM-dd'T'HH:mm:ss.SSS
 *
 * @return NSDateFormatter
 */
+ (NSDateFormatter *)dateFormatter;

/**
 * Formats date time string in format: ddMMyyyyHHmmss
 *
 * @return NSDateFormatter
 */
+ (NSDateFormatter *)dateNoTimeZoneFormatter;

/**
 * Formats date time string in format: ddMMyyyy
 *
 * @return NSDateFormatter
 */
+ (NSDateFormatter *)bankSettlementFormatter;

/**
 * Formats date time string in custom format
 *
 * @return NSDateFormatter
 */
+ (NSDateFormatter *)dateFormaterWithFormatter:(NSString *)format;

@end
