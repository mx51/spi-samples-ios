//
//  NSString+Crypto.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-25.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSString+Crypto.h"

@implementation NSString (Crypto)

- (NSData *)dataFromHexEncoding {
    NSString      *command       = [self stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *commandToSend = [NSMutableData new];
    unsigned char whole_byte;
    char          byte_chars[3] = {'\0', '\0', '\0'};
    int           i;
    
    for (i = 0; i < [command length] / 2; i++) {
        byte_chars[0] = [command characterAtIndex:i * 2];
        byte_chars[1] = [command characterAtIndex:i * 2 + 1];
        whole_byte    = strtol(byte_chars, NULL, 16);
        [commandToSend appendBytes:&whole_byte length:1];
    }
    
    return [commandToSend copy];
}

@end
