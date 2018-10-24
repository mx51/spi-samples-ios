//
//  SPIRepeatingTimer.m
//  SPIClient-iOS
//
//  Created by Chris Hulbert on 14/9/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIRepeatingTimer.h"

/// Full description of this class is in the header.
@implementation SPIRepeatingTimer {
    dispatch_queue_t queue;
    dispatch_source_t timer;
}

- (instancetype)initWithQueue:(char const *)queueLabel interval:(NSTimeInterval)interval block:(dispatch_block_t)block {
    if (self = [super init]) {
        queue = dispatch_queue_create(queueLabel, DISPATCH_QUEUE_SERIAL);
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        uint64_t nsec = (uint64_t)(interval * NSEC_PER_SEC);
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, nsec), // First fire.
                                  nsec, // Repeat frequency.
                                  NSEC_PER_SEC/10); // Leeway of .1s
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return self;
}

@end
