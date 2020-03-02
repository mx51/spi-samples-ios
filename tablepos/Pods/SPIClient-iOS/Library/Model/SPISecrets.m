//
//  SPISecrets.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-25.
//  Copyright © 2017 mx51. All rights reserved.
//

#import "NSString+Crypto.h"
#import "SPISecrets.h"

@implementation SPISecrets

- (instancetype)initWithEncKey:(NSString *)encKey hmacKey:(NSString *)hmacKey {
    self = [super init];
    
    if (self) {
        _encKey = encKey.copy;
        _hmacKey = hmacKey.copy;
        
        _encKeyData = [_encKey dataFromHexEncoding];
        _hmacKeyData = [_hmacKey dataFromHexEncoding];
    }
    
    return self;
}

@end
