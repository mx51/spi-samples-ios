//
//  NSData+Crypto.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Crypto)

- (NSData *)encryptForKey:(NSData *)key iv:(unsigned char[])iv;

- (NSData *)decryptForKey:(NSData *)key iv:(unsigned char[])iv;

- (NSData *)SHA256;

- (NSString *)hexString;

@end
