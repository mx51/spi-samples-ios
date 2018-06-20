//
//  SPIPingHelper.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SPIMessage;

@interface SPIPongHelper : NSObject

+ (SPIMessage *)generatePongRequest:(SPIMessage *)ping;

@end

@interface SPIPingHelper : NSObject

+ (SPIMessage *)generatePingRequest;

@end
