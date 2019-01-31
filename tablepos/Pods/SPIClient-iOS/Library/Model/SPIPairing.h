//
//  SPIPairing.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-26.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SPIMessage;
@class SPISecrets;
@class SPIKeyResponse;

/**
 * Pairing Interaction 1: Outgoing
 */
@interface SPIPairingRequest : NSObject

- (SPIMessage *)toMessage;

@end

/**
 * Pairing Interaction 2: Incoming
 */
@interface SPIKeyRequest : NSObject

@property (nonatomic, readonly, copy) NSString *requestId;
@property (nonatomic, readonly, copy) NSString *aenc;
@property (nonatomic, readonly, copy) NSString *ahmac;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end

/**
 * Pairing Interaction 3: Outgoing
 */
@interface SPIKeyResponse : NSObject

@property (nonatomic, readonly, copy) NSString *requestId;
@property (nonatomic, readonly, copy) NSString *benc;
@property (nonatomic, readonly, copy) NSString *bhmac;

- (instancetype)initWithRequestId:(NSString *)requestId
                             benc:(NSString *)benc
                            bhmac:(NSString *)bhmac;

- (SPIMessage *)toMessage;

@end

/**
 * Pairing Interaction 4: Incoming
 */
@interface SPIKeyCheck : NSObject

@property (nonatomic, readonly, copy) NSString *confirmationCode;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end

/**
 * Pairing Interaction 5: Incoming
 */
@interface SPIPairResponse : NSObject

@property (nonatomic, readonly) BOOL isSuccess;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end

/**
 * Holder class for Secrets and KeyResponse, so that we can use them together in
 * method signatures.
 */
@interface SPISecretsAndKeyResponse : NSObject

@property (nonatomic, readonly) SPISecrets *secrets;
@property (nonatomic, readonly, copy) SPIKeyResponse *keyResponse;

- (instancetype)initWithSecrets:(SPISecrets *)secrets
                    keyResponse:(SPIKeyResponse *)keyResponse;

@end

@interface SPIDropKeysRequest : NSObject

- (SPIMessage *)toMessage;

@end
