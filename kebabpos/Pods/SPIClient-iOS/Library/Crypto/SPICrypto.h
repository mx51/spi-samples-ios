//
//  SPICrypto.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-25.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPICrypto : NSObject

/**
 * Encrypt a block using a <see cref="CipherMode"/> of CBC and a <see cref="PaddingMode"/> of PKCS7.
 *
 * @param message Message
 * @param key key
 * @return NSString
 */
+ (NSString *)aesEncryptMessage:(NSString *)message key:(NSData *)key;

/**
 * Decrypt a block using a <see cref="CipherMode"/> of CBC and a <see cref="PaddingMode"/> of PKCS7.
 *
 * @param message Message
 * @param key key
 * @return NSString
 */
+ (NSString *)aesDecryptEncMessage:(NSString *)message key:(NSData *)key;

/**
 * Calculates the HMACSHA256 signature of a message.
 *
 * @param message Message
 * @param key key
 * @return NSString
 */
+ (NSString *)hmacSignatureMessage:(NSString *)message key:(NSData *)key;

@end
