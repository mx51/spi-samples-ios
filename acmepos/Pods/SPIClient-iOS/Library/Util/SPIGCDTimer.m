//
//  SPIGCDTimer.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2018-01-28.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIGCDTimer.h"

@interface SPIGCDTimer ()
@property (nonatomic, strong, readonly) dispatch_source_t timer;
@end

@implementation SPIGCDTimer

- (instancetype)initWithObject:(id)obj queue:(char const *)queueLabel {
    self = [super init];
    
    if (self) {
        _obj   = obj;
        _queue = dispatch_queue_create(queueLabel, dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));
    }
    
    return self;
}

- (void)_cancel {
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (void)dealloc {
    [self _cancel];
    _queue = nil;
}

- (void)afterDelay:(NSTimeInterval)delay repeat:(BOOL)repeat block:(void (^)(id self))block {
    
    [self performWhileLocked:^{
        
        if (_timer == nil) _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
        
        if (_timer) {
            dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), delay * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
            
            dispatch_source_set_event_handler(_timer, ^{
                block(_obj);
                
                if (!repeat) {
                    [self _cancel];
                }
            });
            
            dispatch_resume(_timer);
        }
    }];
}

- (void)performWhileLocked:(dispatch_block_t)block {
    if (_queue)
        dispatch_sync(_queue, block);
}

- (void)cancel {
    [self performWhileLocked:^{
        [self _cancel];
    }];
}

@end
