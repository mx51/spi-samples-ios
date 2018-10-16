//
//  SPIRepeatingTimer.h
//  SPIClient-iOS
//
//  Created by Chris Hulbert on 14/9/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

/// This is a repeating timer that automatically invalidates self when it gets deallocated.
/// This is handy for creating repeating timers that do not cause memory leaks.
/// It uses GCD to avoid the circular leaks typical of NSTimer repeating timers.
@interface SPIRepeatingTimer : NSObject

/// Your object should retain the returned value, and to avoid a leak, block should weakly reference your object.
/// Your block will be called on a background thread/queue.
/// This will happily work with an interval = 0, in which case the block is continually repeated, and is recommended
/// to have sleep(N) inside to keep CPU usage reasonable. I've done tests, and with interval=0, you can still push
/// async blocks onto the queue and they will get executed, so it's not like GCD enqueues a zillion copies of the block.
- (instancetype)initWithQueue:(char const *)queueLabel interval:(NSTimeInterval)interval block:(dispatch_block_t)block;

@end
