//
//  SPIPingHelper.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIPingHelper.h"
#import "SPIMessage.h"
#import "SPIRequestIdHelper.h"

@implementation SPIPongHelper

+ (SPIMessage *)generatePongRequest:(SPIMessage *)ping {
    return [[SPIMessage alloc] initWithMessageId:ping.mid eventName:SPIPongKey data:nil needsEncryption:YES];
}

@end

@implementation SPIPingHelper

+ (SPIMessage *)generatePingRequest {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"ping"]  eventName:SPIPingKey data:nil needsEncryption:YES];
}

@end
