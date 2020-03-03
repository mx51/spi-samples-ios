//
//  SPIDiffieHellman.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-24.
//  Copyright © 2017 mx51. All rights reserved.
//

#import "SPIDiffieHellman.h"

#import "JKBigInteger.h"

@implementation SPIDiffieHellman

+ (JKBigInteger *)publicKeyWithPrimeP:(JKBigInteger *)primeP
                               primeG:(JKBigInteger *)primeG
                           privateKey:(JKBigInteger *)privateKey {
    
    return [primeG pow:privateKey andMod:primeP];
}

+ (JKBigInteger *)secretWithPrimeP:(JKBigInteger *)primeP
                    theirPublicKey:(JKBigInteger *)theirPublicKey
                    yourPrivateKey:(JKBigInteger *)yourPrivateKey {
    
    // s = A**b mod p
    return [theirPublicKey pow:yourPrivateKey andMod:primeP];
}

+ (JKBigInteger *)randomPrivateKey:(JKBigInteger *)p {
    
    NSString        *maxIntString    = p.stringValue; // this is our maximum number represented as a string, example "2468"
    NSMutableString *randomIntString = [NSMutableString new]; // we will build our random number as a string
    __block BOOL    below            = NO;
    
    [maxIntString enumerateSubstringsInRange:NSMakeRange(0, maxIntString.length)
                                     options:NSStringEnumerationByComposedCharacterSequences
                                  usingBlock:^(NSString *_Nullable thisDigit, NSRange substringRange, NSRange enclosingRange, BOOL *_Nonnull stop) {
                                      
                                      // we need to pick a digit that is equal or smaller than this one.
                                      int maxDigit = !below ? thisDigit.intValue : 9;
                                      int rDigit = arc4random_uniform(10);
                                      
                                      if (rDigit > maxDigit) {
                                          rDigit = 0;
                                      }
                                      
                                      [randomIntString appendString:[NSString stringWithFormat:@"%d", rDigit]];
                                      
                                      if (rDigit < maxDigit) {
                                          // We've picked a digit smaller than the corresponding one in the maximum.
                                          // So from now on, any digit is good.
                                          below = YES;
                                      }
                                  }];
    
    return [[JKBigInteger alloc] initWithString:randomIntString];
}

@end
