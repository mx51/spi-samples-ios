//
//  NSDateFormatter+Util.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSDateFormatter+Util.h"

@implementation NSDateFormatter (Util)

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateFormatter = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS"];
    });
    
    return dateFormatter;
}

+ (NSDateFormatter *)dateNoTimeZoneFormatter {
    static NSDateFormatter *dateFormatter = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        [dateFormatter setDateFormat:@"ddMMyyyyHHmmss"];
    });
    
    return dateFormatter;
}

@end
