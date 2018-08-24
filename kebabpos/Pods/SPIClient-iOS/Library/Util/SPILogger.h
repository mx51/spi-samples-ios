//
//  SPILogger.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const SPILogNotificationKey;

// Swift cannot call variadic functions
void SPILogMsg(NSString *format);

void SPILog(NSString *format, ...);

// Delegate for logging actions.
@protocol SPILogDelegate <NSObject>
- (void)log:(NSString *)message;
@end

// Container for logging actions.
@interface SPILogger : NSObject

// Optional delegate for observing all log messages.
@property (nonatomic, weak) id<SPILogDelegate> delegate;

- (void)log:(NSString *)message;

+ (instancetype)sharedInstance;

@end
