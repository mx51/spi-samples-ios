//
//  APPosPairTest.m
//  AcmePosTests
//
//  Created by Yoo-Jin Lee on 2018-01-18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "APPosBaseTest.h"
#import "SPILogger.h"

@interface APPosPairTest : APPosBaseTest

@end

@implementation APPosPairTest

- (void)testPair {
    [super setupConnection];
}

#pragma mark - SPIDelegate

- (void)spi:(SPIClient *)spi statusChanged:(SPIState *)state {
    SPILog(@"statusChanged %@", state);
    [super printStatusAndAction:state];
}

- (void)spi:(SPIClient *)spi pairingFlowStateChanged:(SPIState *)state {
    SPILog(@"pairingFlowStateChanged %@", state);
    [super printStatusAndAction:state];
}

- (void)spi:(SPIClient *)spi transactionFlowStateChanged:(SPIState *)state {
    SPILog(@"transactionFlowStateChanged %@", state);
}

- (void)spi:(SPIClient *)spi secretsChanged:(SPISecrets *)newSecrets state:(SPIState *)state {
    SPILog(@"secretsChanged %@", newSecrets);
    [self printStatusAndAction:state];
}

- (BOOL)printStatusAndAction:(SPIState *)state {
    BOOL result = [super printStatusAndAction:state];

    if (state.status == SPIStatusPairedConnected) {
        XCTAssertTrue(YES);
        [self.expectation fulfill];
        self.expectation = nil;
        return YES;
    }

    return result;
}

@end
