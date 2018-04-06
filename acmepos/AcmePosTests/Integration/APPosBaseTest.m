//
//  APPosTest.m
//  AcmePosTests
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "APPosBaseTest.h"

@implementation APPosBaseTest

- (void)setUp {
    [super setUp];

    self.spi                   = [SPIClient new];
    self.didProcessCommandDict = @{}.mutableCopy;

}

- (void)tearDown {
    [super tearDown];
    [self.spi unpair];
}

- (void)clearDefaults {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSDictionary   *dict = [defs dictionaryRepresentation];

    for (id key in dict) {
        [defs removeObjectForKey:key];
    }

    [defs synchronize];
}

- (void)setupConnection {
    self.expectation = [self expectationWithDescription:@"success"];

    self.spi.eftposAddress = @"emulator-prod.herokuapp.com";
    self.spi.posId         = @"ACMEPOS3TEST";
    self.spi.delegate      = self;

    if ([self.spi start]) {
        [self.spi pair];
    }

    [self waitForExpectationsWithTimeout:60 handler:^(NSError *error) {
         if (error) XCTAssertFalse(YES);
     }];
}

- (BOOL)printStatusAndAction:(SPIState *)state {
    SPILog(@"# ----------- DEBUG ------------");
    SPILog(@"currentPairState %ld",         state.status);
    SPILog(@"currentFlow %ld",              state.flow);
    SPILog(@"currentPairingFlowState %@",   state.pairingFlowState);
    SPILog(@"isAwaitingCheckFromEftpos %@", @(state.pairingFlowState.isAwaitingCheckFromEftpos));
    SPILog(@"isAwaitingCheckFromPos %@",    @(state.pairingFlowState.isAwaitingCheckFromPos));
    SPILog(@"isFinished %@",                @(state.pairingFlowState.isFinished));
    SPILog(@"# ----------- AVAILABLE ACTIONS ------------");

    switch (state.status) {

        case SPIStatusUnpaired:

            switch (state.flow) {
                case SPIFlowIdle:
                    SPILog(@"# [pos_id:MYPOSNAME] - sets your POS instance ID");
                    SPILog(@"# [eftpos_address:10.10.10.10] - sets IP address of target EFTPOS");
                    SPILog(@"# [pair] - start pairing");
                    break;

                case SPIFlowPairing: {
                    SPIPairingFlowState *pairingState = state.pairingFlowState;

                     // && !pairingState.isAwaitingCheckFromEftpos
                    if (pairingState.isAwaitingCheckFromPos) {
                        SPILog(@"# [pair_confirm] - confirm the code matches");

                        if (!self.didProcessCommandDict[@(APCommandPairConfirm)]) {
                            self.didProcessCommandDict[@(APCommandPairConfirm)] = @YES;
                            [self.spi pairingConfirmCode];
                            return YES;
                        }
                    }

                    if (!pairingState.isFinished) {
                        SPILog(@"# [pair_cancel] - cancel pairing process");
                    } else {
                        SPILog(@"# [ok] - acknowledge pairing");
                    }
                } break;

                default:
                    SPILog(@"# .. Unexpected Flow .. %@", @(state.flow));
                    break;
            }

            break;

        case SPIStatusPairedConnected:
            SPILog(@"currentPairState SPIStatusPairedConnected, currentFlow=%@", @(state.flow));

            switch (state.flow) {

                case SPIFlowIdle:
                    SPILog(@"# [purchase:1981] - initiate a payment of $19.81");
                    SPILog(@"# [refund:1891] - initiate a refund of $18.91");
                    SPILog(@"# [settle] - Initiate Settlement");
                    SPILog(@"# [unpair] - unpair and disconnect");

                    break;

                case SPIFlowTransaction:
                    if (state.txFlowState.isAwaitingSignatureCheck) {
                        SPILog(@"# [tx_sign_accept] - Accept Signature");
                        SPILog(@"# [tx_sign_decline] - Decline Signature");
                    }

                    if (!state.txFlowState.isFinished) {
                        SPILog(@"# [tx_cancel] - Attempt to Cancel Transaction");
                    } else {
                        SPILog(@"# [ok] - acknowledge transaction");
                    }

                    break;

                case SPIFlowPairing:// Paired, Pairing - we have just finished the pairing flow. OK to ack.
                    SPILog(@"# [ok] - acknowledge pairing transaction Flow");

                    if (!self.didProcessCommandDict[@(APCommandPairAcknowledge)]) {
                        self.didProcessCommandDict[@(APCommandPairAcknowledge)] = @YES;

                        [self.spi ackFlowEndedAndBackToIdle:^(BOOL alreadyMovedToIdleState, SPIState *state) {
                             [self printStatusAndAction:state];
                         }];

                        return YES;
                    }

                    break;

                default:
                    SPILog(@"# .. Unexpected Flow .. %@", @(state.flow));
                    break;
            }

            break;

        default:
            break;
    }

    return NO;
}

- (void)spi:(SPIClient *)spi error:(NSString *)error state:(SPIState *)state {
    [self.spi pairingCancel];
    [self.didProcessCommandDict removeAllObjects];
}

@end
