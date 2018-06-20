//
//  SPIKeyRollingHelper.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-27.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSData+Crypto.h"
#import "NSString+Crypto.h"
#import "SPICrypto.h"
#import "SPIKeyRollingHelper.h"
#import "SPIMessage.h"
#import "SPISecrets.h"

@implementation SPIKeyRollingResult

- (instancetype)initWithKeyRollingConfirmation:(SPIMessage *)keyRollingConfirmation
                                       secrets:(SPISecrets *)secrets {
    self = [super init];
    
    if (self) {
        _keyRollingConfirmation = keyRollingConfirmation;
        _secrets = secrets;
    }
    
    return self;
}

@end

@implementation SPIKeyRollingHelper

+ (SPIKeyRollingResult *)performKeyRollingWithMessage:(SPIMessage *)krRequest
                                       currentSecrets:(SPISecrets *)currentSecrets {
    
    SPIMessage *m = [[SPIMessage alloc] initWithMessageId:krRequest.mid
                                                eventName:SPIKeyRollResponseKey
                                                     data:@{@"status" : @"confirmed"}
                                          needsEncryption:YES];
    SPISecrets *newSecrets = [[SPISecrets alloc] initWithEncKey:[[[currentSecrets.encKey dataFromHexEncoding] SHA256] hexString]
                                                        hmacKey:[[[currentSecrets.hmacKey dataFromHexEncoding] SHA256] hexString]];
    return [[SPIKeyRollingResult alloc] initWithKeyRollingConfirmation:m secrets:newSecrets];
}

@end
