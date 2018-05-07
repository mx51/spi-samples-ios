//
//  SPISettleRequest.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPISettleRequest.h"
#import "SPIMessage.h"
#import "SPIRequestIdHelper.h"

@implementation SPISettleRequest

- (instancetype)initWithSettleId:(NSString *)settleId {
    self = [super init];
    
    if (self) {
        _settleId = [settleId copy];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"stl"] eventName:SPISettleRequestKey
                                            data:nil needsEncryption:YES];
}

@end

@implementation SPISettlement

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _requestId = message.mid;
        _message   = message;
        _isSuccess = message.isSuccess;
    }
    
    return self;
}

- (NSString *)getResponseText {
    return [self.message getDataStringValue:@"host_response_text"];
}

- (NSString *)getReceipt {
    return [self.message getDataStringValue:@"merchant_receipt"];
}

@end
