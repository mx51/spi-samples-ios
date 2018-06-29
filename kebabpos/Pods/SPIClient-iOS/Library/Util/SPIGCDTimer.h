//
//  SPIGCDTimer.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2018-01-28.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

@interface SPIGCDTimer : NSObject

@property (nonatomic, weak, readonly) id obj;
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

- (instancetype)initWithObject:(id)obj queue:(char const *)queueLabel;

- (void)afterDelay:(NSTimeInterval)delay repeat:(BOOL)repeat block:(void (^)(id self))block;

- (void)performWhileLocked:(void (^)(void))block;

- (void)cancel;

@end
