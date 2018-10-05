//
//  SPIPairing.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-26.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIMessage.h"
#import "SPIPairing.h"
#import "SPIRequestIdHelper.h"

@implementation SPIPairingRequest

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"pr"]
                                       eventName:SPIPairRequestKey
                                            data:@{
                                                   @"padding": @YES
                                                   }
                                 needsEncryption:NO];
}

@end

@implementation SPIKeyRequest

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _requestId = message.mid;
        _aenc = [message getDataDictionaryValue:@"enc"][@"A"];
        _ahmac = [message getDataDictionaryValue:@"hmac"][@"A"];
    }
    
    return self;
}

@end

@implementation SPIKeyResponse

- (instancetype)initWithRequestId:(NSString *)requestId
                             benc:(NSString *)benc
                            bhmac:(NSString *)bhmac {
    
    self = [super init];
    
    if (self) {
        _requestId = [requestId copy];
        _benc = [benc copy];
        _bhmac = [bhmac copy];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.requestId
                                       eventName:SPIKeyResponseKey
                                            data:@{
                                                   @"enc": @{@"B": self.benc},
                                                   @"hmac": @{@"B": self.bhmac}
                                                   }
                                 needsEncryption:NO];
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
        _isSuccess =
        [message getDataBoolValue:@"success" defaultIfNotFound:false];
    }
    
    return self;
}

@end

@implementation SPISecretsAndKeyResponse

- (instancetype)initWithSecrets:(SPISecrets *)secrets
                    keyResponse:(SPIKeyResponse *)keyResponse {
    
    self = [super init];
    
    if (self) {
        _secrets = secrets;
        _keyResponse = keyResponse;
    }
    
    return self;
}

@end

@implementation SPIDropKeysRequest

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"drpkys"]
                                       eventName:SPIDropKeysAdviceKey
                                            data:nil
                                 needsEncryption:true];
}

@end
