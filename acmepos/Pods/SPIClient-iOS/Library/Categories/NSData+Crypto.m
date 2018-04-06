//
//  NSData+Crypto.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSData+Crypto.h"

#import <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>

@implementation NSData (Crypto)

- (NSData *)SHA256 {
    unsigned int  outputLength = CC_SHA256_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_SHA256(self.bytes, (unsigned int)self.length, output);
    return [NSData dataWithBytes:output length:outputLength];
}

- (NSData *)encryptForKey:(NSData *)key iv:(unsigned char [])iv {
    return [self cryptForOperation:kCCEncrypt key:key iv:iv];
}

- (NSData *)decryptForKey:(NSData *)key iv:(unsigned char [])iv {
    return [self cryptForOperation:kCCDecrypt key:key iv:iv];
}

- (NSData *)cryptForOperation:(CCOperation)op key:(NSData *)key iv:(unsigned char [])iv {
    NSData *data   = self;
    NSData *result = nil;
    
    unsigned char cKey[kCCKeySizeAES256];
    bzero(cKey, sizeof(cKey));
    [key getBytes:cKey length:kCCKeySizeAES256];
    
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void   *buffer    = malloc(bufferSize);
    
    // do decrypt
    size_t          decryptedSize = 0;
    CCCryptorStatus cryptStatus   = CCCrypt(op,
                                            kCCAlgorithmAES128,
                                            kCCOptionPKCS7Padding,
                                            cKey,
                                            kCCKeySizeAES256,
                                            iv,
                                            [data bytes],
                                            [data length],
                                            buffer,
                                            bufferSize,
                                            &decryptedSize);
    
    if (cryptStatus == kCCSuccess) {
        result = [NSData dataWithBytesNoCopy:buffer length:decryptedSize];
    } else {
        free(buffer);
        NSLog(@"[ERROR] failed to decrypt| CCCryptoStatus: %d", cryptStatus);
    }
    
    return result;
}

- (NSString *)hexString {
    NSUInteger    length    = self.length;
    unichar       *hexChars = (unichar *)malloc(sizeof(unichar) * (length * 2));
    unsigned char *bytes    = (unsigned char *)self.bytes;
    
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = bytes[i] / 16;
        
        if (c < 10) {
            c += '0';
        } else {
            c += 'A' - 10;
        }
        
        hexChars[i * 2] = c;
        
        c = bytes[i] % 16;
        
        if (c < 10) {
            c += '0';
        } else {
            c += 'A' - 10;
        }
        
        hexChars[i * 2 + 1] = c;
    }
    
    return [[NSString alloc] initWithCharactersNoCopy:hexChars length:length * 2 freeWhenDone:YES];
}

@end
