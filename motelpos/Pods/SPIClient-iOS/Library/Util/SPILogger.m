//
//  SPILogger.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 mx51. All rights reserved.
//

#import "SPILogger.h"
#import <Foundation/Foundation.h>

NSString *const SPILogNotificationKey = @"SPILogNotificationKey";

void SPILogMsg(NSString *message) {
    [[SPILogger sharedInstance] log:message];
}

void SPILog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    SPILogMsg(message);
    va_end(args);
}

@implementation SPILogger

+ (instancetype)sharedInstance {
    static SPILogger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [SPILogger new];
    });
    return sharedInstance;
}

- (void)log:(NSString *)message {
    if (_delegate) {
        [_delegate log:message];
    }
    NSLog(@"%@", message);
}

@end
