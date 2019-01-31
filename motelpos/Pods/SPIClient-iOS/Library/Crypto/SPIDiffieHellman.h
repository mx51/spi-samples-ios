//
//  SPIDiffieHellman.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-24.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JKBigInteger.h"

/**
 * This class implements the Diffie-Hellman algorithm using BigIntegers.
 * It can do the 3 main things:
 * 1. Generate a random Private Key for you.
 * 2. Generate your Public Key based on your Private Key.
 * 3. Generate the Secret given their Public Key and your Private Key
 * p and g are the shared constants for the algorithm, aka primeP and primeG.
 */
@interface SPIDiffieHellman : NSObject

/**
 * Generates a random Private Key that you can use.
 *
 * @param p JKBigInteger
 * @return JKBigInteger
 */
+ (JKBigInteger *)randomPrivateKey:(JKBigInteger *)p;

/**
 * Calculates the Public Key from a Private Key.
 *
 * @param primeP JKBigInteger
 * @param primeG JKBigInteger
 * @param privateKey JKBigInteger
 * @return JKBigInteger
 */
+ (JKBigInteger *)publicKeyWithPrimeP:(JKBigInteger *)primeP
                               primeG:(JKBigInteger *)primeG
                           privateKey:(JKBigInteger *)privateKey;

/**
 * Calculates the shared secret given their Public Key (A) and your Private Key (b)
 *
 * @param primeP JKBigInteger
 * @param theirPublicKey JKBigInteger
 * @param yourPrivateKey JKBigInteger
 * @return JKBigInteger
 */
+ (JKBigInteger *)secretWithPrimeP:(JKBigInteger *)primeP
                    theirPublicKey:(JKBigInteger *)theirPublicKey
                    yourPrivateKey:(JKBigInteger *)yourPrivateKey;

@end
