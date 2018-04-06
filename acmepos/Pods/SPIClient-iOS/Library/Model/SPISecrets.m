//
//  SPISecrets.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-25.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPISecrets.h"
#import "NSString+Crypto.h"

@implementation SPISecrets

- (instancetype)initWithEncKey:(NSString *)encKey
                       hmacKey:(NSString *)hmacKey {
    self = [super init];
    
    if (self) {
        _encKey  = encKey.copy;
        _hmacKey = hmacKey.copy;
        
        _encKeyData  = [_encKey dataFromHexEncoding];
        _hmacKeyData = [_hmacKey dataFromHexEncoding];
    }
    
    return self;
}

@end
