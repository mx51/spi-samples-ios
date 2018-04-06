//
//  APPosPurchaseTest.m
//  AcmePosTests
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "APPosBaseTest.h"
#import "SPILogger.h"

@interface APPosPurchaseTest : APPosBaseTest
@end

@implementation APPosPurchaseTest

- (void)testPurchase {
    [super setupConnection];
}

- (BOOL)printStatusAndAction:(SPIState *)state {
    if ([super printStatusAndAction:state]) return NO;

    switch (state.status) {

        case SPIStatusUnpaired:
            switch (state.flow) {
                case SPIFlowIdle:
                    SPILog(@"# [pos_id:MYPOSNAME] - sets your POS instance ID");
                    SPILog(@"# [eftpos_address:10.10.10.10] - sets IP address of target EFTPOS");
                    SPILog(@"# [pair] - start pairing");
                    break;

                case SPIFlowPairing:
                     //Base class is taking care of this
                    break;

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
                    
                    if (!self.didProcessCommandDict[@(APCommandPurchaseInitiate)]) {
                        SPILog(@"APCommandPurchaseInitiate");
                        self.didProcessCommandDict[@(APCommandPurchaseInitiate)] = @YES;
                        
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3. * NSEC_PER_SEC),
                                       dispatch_get_main_queue(),
                                       ^(void) {
                                           [self.spi initiatePurchaseTx:[SPIRequestIdHelper idForString:@"prchs"]  amountCents:100 completion:^(SPIInitiateTxResult *result) {
                                               XCTAssertTrue(result.isInitiated);
                                           }];
                                       });
                    }

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
                    //                    SPILog(@"# [ok] - acknowledge pairing transaction Flow");
                    // base class should take care of this

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

- (void)startPurchase:(SPIState *)state {
    SPILog(@"startPurchase");

    [self.spi initiatePurchaseTx:[SPIRequestIdHelper idForString:@"prchs"]  amountCents:100 completion:^(SPIInitiateTxResult *result) {
         XCTAssertTrue(result.isInitiated);
     }];
}

#pragma mark - SPIDelegate

- (void)spi:(SPIClient *)spi statusChanged:(SPIState *)state {
    SPILog(@"statusChanged %@", state);
    [self printStatusAndAction:state];
}

- (void)spi:(SPIClient *)spi pairingFlowStateChanged:(SPIState *)state {
    SPILog(@"pairingFlowStateChanged %@", state);
    [self printStatusAndAction:state];
}

- (void)spi:(SPIClient *)spi transactionFlowStateChanged:(SPIState *)state {
    SPILog(@"transactionFlowStateChanged %@", state);

    SPILog(@"# --------- OnTxFlowStateChanged -----------");
    SPILog(@"# Id: %@",                       state.txFlowState.tid);
    SPILog(@"# Type: %@",                     @(state.txFlowState.type));
    SPILog(@"# RequestSent: %@",              @(state.txFlowState.isRequestSent));
    SPILog(@"# WaitingForSignature: %@",      @(state.txFlowState.isAwaitingSignatureCheck));
    SPILog(@"# Attempting to Cancel : %@",    @(state.txFlowState.isAttemptingToCancel));
    SPILog(@"# Finished: %@",                 @(state.txFlowState.isFinished));
    SPILog(@"# Success: %@",                  @(state.txFlowState.successState));
    SPILog(@"# Display Message: %@",          state.txFlowState.displayMessage);

    if (state.txFlowState.isAwaitingSignatureCheck) {
         // We need to print the receipt for the customer to sign.
        SPILog([state.txFlowState.signatureRequiredMessage getMerchantReceipt]);
    }

     // If the transaction is finished, we take some extra steps.
    if (state.txFlowState.isFinished) {

        if (state.txFlowState.successState == SPIMessageSuccessStateUnknown) {
             // TH-4T, TH-4N, TH-2T - This is the dge case when we can't be sure what happened to the transaction.
             // Invite the merchant to look at the last transaction on the EFTPOS using the dicumented shortcuts.
             // Now offer your merchant user the options to:
             // A. Retry the transaction from scrtatch or pay using a different method - If Merchant is confident that tx didn't go through.
             // B. Override Order as Paid in you POS - If Merchant is confident that payment went through.
             // C. Cancel out of the order all together - If the customer has left / given up without paying
            SPILog(@"# NOT SURE IF WE GOT PAID OR NOT. CHECK LAST TRANSACTION MANUALLY ON EFTPOS!");
        } else {
             // We have a result...
            switch (state.txFlowState.type) {
                // Depending on what type of transaction it was, we might act diffeently or use different data.
                case SPITransactionTypePurchase:

                    if (state.txFlowState.response != nil) {
                        SPIPurchaseResponse *purchaseResponse = [[SPIPurchaseResponse alloc] initWithMessage:state.txFlowState.response];
                        SPILog(@"# Scheme: %@",   purchaseResponse.schemeName);
                        SPILog(@"# Response: %@", purchaseResponse.getResponseText);
                        SPILog(@"# RRN: %@",      [purchaseResponse getRRN]);
                        SPILog(@"# Error: %@",    state.txFlowState.response.error);
                        SPILog(@"# Customer Receipt:");
                        SPILog(@"%@",             [purchaseResponse getCustomerReceipt]);
                    } else {
                        // We did not even get a response, like in the case of a time-out.
                    }

                    if (state.txFlowState.isFinished && state.txFlowState.successState == SPIMessageSuccessStateSuccess) {
                         // TH-6A
                        SPILog(@"# HOORAY WE GOT PAID (TH-7A). CLOSE THE ORDER!");

                        XCTAssertTrue(YES);
                        [self.expectation fulfill];

                    } else {
                         // TH-6E
                        SPILog(@"# WE DIDN'T GET PAID. RETRY PAYMENT (TH-5R) OR GIVE UP (TH-5C)!");
                    }

                    break;

                case SPITransactionTypeRefund:

                    if (state.txFlowState.response != nil) {
                        SPIRefundResponse *refundResponse = [[SPIRefundResponse alloc] initWithMessage:state.txFlowState.response];

                        SPILog(@"# Scheme: %@",   refundResponse.schemeName);
                        SPILog(@"# Response: %@", refundResponse.getResponseText);
                        SPILog(@"# RRN: %@",      refundResponse.getRRN);
                        SPILog(@"# Error: %@",    state.txFlowState.response.error);
                        SPILog(@"# Customer Receipt:");
                        SPILog(@"%@",             [refundResponse getCustomerReceipt]);
                    } else {
                        // We did not even get a response, like in the case of a time-out.
                    }

                    break;

                case SPITransactionTypeSettle:

                    if (state.txFlowState.response != nil) {
                        SPISettlement *settleResponse = [[SPISettlement alloc] initWithMessage:state.txFlowState.response];
                        SPILog(@"# Response: %@", [settleResponse getResponseText]);
                        SPILog(@"# Error: %@",    state.txFlowState.response.error);
                        SPILog(@"# Merchant Receipt:");
                        SPILog([settleResponse getReceipt]);
                    } else {
                        // We did not even get a response, like in the case of a time-out.
                    }

                    break;

                default:
                    break;
            }
        }
    }

     // Let's show the user what options he has at this stage.
    [self printStatusAndAction:state];
}

- (void)spi:(SPIClient *)spi secretsChanged:(SPISecrets *)newSecrets state:(SPIState *)state {
    SPILog(@"secretsChanged %@", newSecrets);
    [self printStatusAndAction:state];
}

@end
