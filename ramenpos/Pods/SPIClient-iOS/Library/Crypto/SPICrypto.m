//
//  SPICrypto.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-25.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPICrypto.h"

#import <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>

#import "NSString+Crypto.h"
#import "NSData+Crypto.h"

static unsigned char AesIV [] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

@implementation SPICrypto

+ (NSString *)aesEncryptMessage:(NSString *)message key:(NSData *)key {
    NSData *data = [[message dataUsingEncoding:NSUTF8StringEncoding] encryptForKey:key iv:AesIV];
    return [data hexString];
}

+ (NSString *)aesDecryptEncMessage:(NSString *)enc key:(NSData *)key {
    if (key == nil) {
        @throw [NSException exceptionWithName:@"Nil" reason:@"key is nil" userInfo:nil];
    }
    
    NSData *data = [[enc dataFromHexEncoding] decryptForKey:key iv:AesIV];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSString *)hmacSignatureMessage:(NSString *)message key:(NSData *)keyData {
    const char *cKey  = [keyData bytes];
    const char *cData = [message cStringUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, cKey, keyData.length, cData, strlen(cData), cHMAC);
    
    NSData *d = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
    return [d hexString];
}

@end
