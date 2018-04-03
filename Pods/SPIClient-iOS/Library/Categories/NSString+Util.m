//
//  NSString+Util.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSString+Util.h"
#import "NSDateFormatter+Util.h"

@implementation NSString (Util)

- (NSString *)trim {
    return [self stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSDate *)toDate {
    return [[NSDateFormatter dateFormatter] dateFromString:self];
}

@end
