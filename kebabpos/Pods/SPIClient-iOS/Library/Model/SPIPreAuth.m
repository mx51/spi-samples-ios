//
//  SPIPreAuth.m
//  SPIClient-iOS
//
//  Created by Amir Kamali on 4/6/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIPreAuth.h"

@interface SPIPreAuth () {
    dispatch_queue_t _queue;
    SPIClient *_client;
}

@end

@implementation SPIPreAuth

- (instancetype)init:(SPIClient *)client queue:(dispatch_queue_t)queue {
    _client = client;
    _queue = queue;
    
    return self;
}

@end
