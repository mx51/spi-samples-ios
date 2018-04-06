//
//  SPISecrets.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-25.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPISecrets : NSObject

@property (nonatomic, readonly, copy) NSString *encKey;
@property (nonatomic, readonly, copy) NSString *hmacKey;

@property (nonatomic, copy) NSData *encKeyData;
@property (nonatomic, copy) NSData *hmacKeyData;

- (instancetype)initWithEncKey:(NSString *)encKey
                       hmacKey:(NSString *)hmacKey;

@end
