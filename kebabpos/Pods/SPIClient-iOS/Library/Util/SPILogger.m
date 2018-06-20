//
//  SPILogger.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPILogger.h"
#import <Foundation/Foundation.h>

NSString *const SPILogNotificationKey = @"SPILogNotificationKey";

void SPILogMsg(NSString *message) {
    NSLog(@"%@", message);
}

void SPILog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    SPILogMsg(message);
    va_end(args);
}
