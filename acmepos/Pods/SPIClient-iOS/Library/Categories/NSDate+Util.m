//
//  NSDate+Util.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-25.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSDate+Util.h"
#import "NSDateFormatter+Util.h"

@implementation NSDate (Utils)

- (NSString *)toString {
    return [[NSDateFormatter dateFormatter] stringFromDate:self];
}

@end
