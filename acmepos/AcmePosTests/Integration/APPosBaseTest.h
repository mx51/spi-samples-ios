//
//  APPosTest.h
//  AcmePosTests
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>
#import "SPIClient.h"
#import "SPIRequestIdHelper.h"
#import "SPILogger.h"

typedef NS_ENUM (NSUInteger, APCommand) {
    APCommandFlowUnknown,

    APCommandPosIdUpdatable,
    APCommandEftpoAddressUpdatable,

    APCommandPair,
    APCommandPairConfirm,
    APCommandPairCancel,
    APCommandPairAcknowledge,

    APCommandPurchaseInitiate,
    APCommandPurchaseOk,
    APCommandRefund,
    APCommandSettle,
    APCommandUnpair,
    APCommandTxSignAccept,
    APCommandTxSignDecline,
    APCommandTxCancel,
    APCommandTxAcknowledge,
    APCommandTxPairingAcknowledge,
    APCommandTxUnknown,
};

@interface APPosBaseTest : XCTestCase <SPIDelegate>

@property (nonatomic, strong) SPIClient          *spi;
@property (nonatomic, strong)  XCTestExpectation *expectation;

@property (nonatomic, strong) NSMutableDictionary *didProcessCommandDict;
@property (nonatomic, assign)  BOOL               resetSecrets;

- (void)setupConnection;

/**
 * Returns YES if invoked a oommand.
 *
 * @param state SPIState
 * @return BOOL
 */
- (BOOL)printStatusAndAction:(SPIState *)state;

@end
