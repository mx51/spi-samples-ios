//
//  SPIRequestIdHelper.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-26.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIRequestIdHelper.h"

@interface SPIRequestIdHelper ()

@property (nonatomic, assign) NSUInteger counter;

@end

@implementation SPIRequestIdHelper

+ (instancetype)sharedInstance {
    static SPIRequestIdHelper *sharedInstance = nil;
    static dispatch_once_t   onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [SPIRequestIdHelper new];
        sharedInstance.counter = 1;
    });
    
    return sharedInstance;
}

+ (NSString *)idForString:(NSString *)string {
    NSUInteger counter = [SPIRequestIdHelper sharedInstance].counter++;
    return [NSString stringWithFormat:@"%@%ld", string, counter];
}

@end
