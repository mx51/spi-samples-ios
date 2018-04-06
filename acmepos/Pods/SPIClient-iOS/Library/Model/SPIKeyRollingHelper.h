//
//  SPIKeyRollingHelper.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-27.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPIMessage.h"
#import "SPISecrets.h"

@interface SPIKeyRollingResult : NSObject
@property (nonatomic, readonly, strong) SPIMessage *keyRollingConfirmation;
@property (nonatomic, readonly, strong) SPISecrets *secrets;

- (instancetype)initWithKeyRollingConfirmation:(SPIMessage *)keyRollingConfirmation
                                       secrets:(SPISecrets *)secrets;

@end

@interface SPIKeyRollingHelper : NSObject

+ (SPIKeyRollingResult *)performKeyRollingWithMessage:(SPIMessage *)krRequest
                                       currentSecrets:(SPISecrets *)currentSecrets;

@end
