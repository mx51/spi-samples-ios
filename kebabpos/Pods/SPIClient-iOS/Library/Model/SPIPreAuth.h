//
//  SPIPreAuth.h
//  SPIClient-iOS
//
//  Created by Amir Kamali on 4/6/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SPIClient;
@interface SPIPreAuth : NSObject

- (instancetype)init:(SPIClient *)client queue:(dispatch_queue_t)queue;

@end
