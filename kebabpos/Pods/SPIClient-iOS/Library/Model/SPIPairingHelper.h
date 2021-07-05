//
//  SPIPairingHelper.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-26.
//  Copyright © 2017 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JKBigInteger.h"
#import "SPIPairing.h"

@interface SPIPublicKeyAndSecret : NSObject

@property (nonatomic, readonly, copy) NSString *myPublicKey;
@property (nonatomic, readonly, copy) NSString *sharedSecretKey;

- (id)initWithMyPublicKey:(NSString *)myPublicKey
                secretKey:(NSString *)sharedSecretKey;

@end

/**
 * This static class helps you with the pairing process as documented here:
 * http://www.simplepaymentapi.com/#/api/pairing-process
 */
@interface SPIPairingHelper : NSObject

/**
 * Generates a pairing Request.
 *
 * @return SPIPairingRequest
 */
+ (SPIPairingRequest *)newPairRequest;

/**
 * Calculates/Generates Secrets and KeyResponse given an incoming KeyRequest.
 *
 * @param keyRequest SPIKeyRequest
 * @return Secrets and KeyResponse to send back.
 */
+ (SPISecretsAndKeyResponse *)generateSecretsAndKeyResponseForKeyRequest:(SPIKeyRequest *)keyRequest;

/**
 * Converts an incoming A value into a BigInteger.
 * There are some "gotchyas" here which is why this piece of work is abstracted
 * so it can be tested separately.
 *
 * @param hexStringA NSString
 * @return JKBigInteger
 */
+ (JKBigInteger *)spiAHexStringToBigIntegerForHexStringA:(NSString *)hexStringA;

/**
 * Converts the DH secret BigInteger into the hex-string to be used as the
 * secret. There are some "gotchyas" here which is why this piece of work is
 * abstracted so it can be tested separately. See:
 * http://www.simplepaymentapi.com/#/api/pairing-process
 *
 * @param secretBI Secret as BigInteger
 * @return Secret as Hex-String
 */
+ (NSString *)dhSecretToSPISecret:(JKBigInteger *)secretBI;

/**
 * Turns an incoming "A" value from the PIN pad into the outgoing "B" value
 * and the secret value using DiffieHelmman helper.
 *
 * @param theirPublicKey NSString
 * @return SPIPublicKeyAndSecret
 */
+ (SPIPublicKeyAndSecret *)calculateMyPublicKeyAndSecret:(NSString *)theirPublicKey;

@end
