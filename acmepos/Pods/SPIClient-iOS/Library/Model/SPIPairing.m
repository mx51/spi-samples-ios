//
//  SPIPairing.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-26.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIPairing.h"
#import "SPIMessage.h"
#import "SPIRequestIdHelper.h"

@implementation SPIPairingRequest

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"pr"]
                                       eventName:SPIPairRequestKey
                                            data:@{@"padding":@YES}
                                 needsEncryption:NO];
}

@end

@implementation SPIKeyRequest

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _requestId = message.mid;
        _aenc      = ((NSDictionary *)message.data[@"enc"])[@"A"];
        _ahmac     = ((NSDictionary *)message.data[@"hmac"])[@"A"];
    }
    
    return self;
}

@end

@implementation SPIKeyResponse

- (instancetype)initWithRequestId:(NSString *)requestId benc:(NSString *)benc bhmac:(NSString *)bhmac {
    self = [super init];
    
    if (self) {
        _requestId = [requestId copy];
        _benc      = [benc copy];
        _bhmac     = [bhmac copy];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.requestId
                                       eventName:SPIKeyResponseKey
                                            data:@{
                                                   @"enc":@{@"B":self.benc},
                                                   @"hmac":@{@"B":self.bhmac}
                                                   } needsEncryption:NO];
}

@end

@implementation SPIKeyCheck
- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _confirmationCode = [message.incomingHmac substringToIndex:6];
        
        NSLog(@"SPIKeyCheck confirmationCode = %@", _confirmationCode);
    }
    
    return self;
}

@end

@implementation SPIPairResponse
- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _isSuccess = ((NSString *)message.data[@"success"]).boolValue;
    }
    
    return self;
}

@end

@implementation SPISecretsAndKeyResponse

- (instancetype)initWithSecrets:(SPISecrets *)secrets keyResponse:(SPIKeyResponse *)keyResponse {
    self = [super init];
    
    if (self) {
        _secrets     = secrets;
        _keyResponse = keyResponse;
    }
    
    return self;
    
}

@end
