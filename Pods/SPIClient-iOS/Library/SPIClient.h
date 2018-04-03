//
//  SPIClient.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPIPurchase.h"
#import "SPISettleRequest.h"
#import "SPIConnection.h"
#import "SPIModels.h"

@class SPIClient;

typedef void (^SPICompletionTxResult)(SPIInitiateTxResult *result);

/**
 * Completion handler
 *
 * @param alreadyMovedToIdleState true means we have moved back to the Idle state. false means current flow was not finished yet.
 * @param state SPIState
 */
typedef void (^SPICompletionState)(BOOL alreadyMovedToIdleState, SPIState *state);

@protocol SPIDelegate <NSObject>

@optional

// Subscribe to this event to know when the CurrentPairingFlowState changes
- (void)spi:(SPIClient *)spi statusChanged:(SPIState *)state;

- (void)spi:(SPIClient *)spi pairingFlowStateChanged:(SPIState *)state;

// When CurrentFlow==Transaction, this represents the state of the transaction process.
- (void)spi:(SPIClient *)spi transactionFlowStateChanged:(SPIState *)state;

// Subscribe to this event to know when the Secrets change, such as at the end of the pairing process,
// or everytime that the keys are periodicaly rolled. You then need to persist the secrets safely
// so you can instantiate SPI with them next time around.
- (void)spi:(SPIClient *)spi secretsChanged:(SPISecrets *)secrets state:(SPIState *)state;

@end

/**
 *
 *  AcmePos is a command line POS that demonstrates connecting to a PIN pad/EFTPOS and accept payments through it.
 *
 *  A word on the terminology. "PIN pad" and "EFTPOS" refer to the same thing. When referring to it in your User Interface
 *  to your merchant users, we recommend using the "EFTPOS" wording. Most of the documentation and code uses the "PIN pad"
 *  wording.
 *
 */
@interface SPIClient : NSObject

// The current state.
@property (nonatomic, readonly) SPIState *state;

// The IP address of the target EFTPOS. Automatically prepends ws://
// Allows you to set the PIN pad address. Sometimes the PIN pad might change IP address
// (we recommend reserving static IPs if possible).
// Either way you need to allow your User to enter the IP address of the PIN pad.
@property (nonatomic, copy)  NSString *eftposAddress;

// Uppercase AlphaNumeric string that Indentifies your POS instance. This value is displayed on the EFTPOS screen.
// Can only be called set in the Unpaired state.
@property (nonatomic, copy)  NSString *posId;

@property (nonatomic, weak) id <SPIDelegate> delegate;

/**
 * If you provide secrets, it will start in PairedConnecting status; Otherwise it will start in Unpaired status.
 *
 * @return BOOL, YES if needs to pair, else NO
 */
- (BOOL)start;

/**
 * Set the pairing secrets encKey and hmacKey
 *
 * @param encKey String
 * @param hmacKey String
 */
- (void)setSecretEncKey:(NSString *)encKey hmacKey:(NSString *)hmacKey;

/**
 * This will connect to the EFTPOS and start the pairing process.
 * Only call this if you are in the Unpaired state.
 * Subscribe to the PairingFlowStateChanged event to get updates on the pairing process.
 */
- (void)pair;

/**
 * Call this when your user clicks yes to confirm the pairing code on your
 * screen matches the one on the EFTPOS.
 */
- (void)pairingConfirmCode;

/**
 *
 * Call this one when a flow is finished and you want to go back to idle state.
 * Typically when your user clicks the "OK" bubtton to acknowldge that pairing is
 * finished, or that transaction is finished.
 * When true, you can dismiss the flow screen and show back the idle screen.
 *
 * @param completion completion handler
 */
- (void)ackFlowEndedAndBackToIdle:(SPICompletionState)completion;

/**
 * Call this if your user clicks CANCEL or NO during the pairing process.
 */
- (void)pairingCancel;

/**
 *
 * Call this when your uses clicks the Unpair button.
 * This will disconnect from the EFTPOS and forget the secrets.
 * The CurrentState is then changed to Unpaired.
 * Call this only if you are not yet in the Unpaired state.
 */
- (void)unpair;

/**
 * Initiates a purchase transaction. Be subscribed to TxFlowStateChanged event to get updates on the process.
 *
 * @param pid Purchase ID
 * @param amountCents NSInteger
 * @param completion SPICompletionTxResult
 */
- (void)initiatePurchaseTx:(NSString *)pid amountCents:(NSInteger)amountCents completion:(SPICompletionTxResult)completion;

/**
 * Initiates a refund transaction. Be subscribed to TxFlowStateChanged event to get updates on the process.
 *
 * @param pid Unique ID
 * @param amountCents NSInteger
 * @param completion SPICompletionTxResult
 */
- (void)initiateRefundTx:(NSString *)pid amountCents:(NSInteger)amountCents completion:(SPICompletionTxResult)completion;

/**
 * Let the EFTPOS know whether merchant accepted or declined the signature
 *
 * @param accepted YES if merchant accepted the signature from customer or else NO
 */
- (void)acceptSignature:(BOOL)accepted;

/**
 * Attempts to cancel a Transaction.
 * Be subscribed to TxFlowStateChanged event to see how it goes.
 * Wait for the transaction to be finished and then see whether cancellation was successful or not.
 */
- (void)cancelTransaction;

/**
 * Initiates a settlement transaction.
 * Be subscribed to TxFlowStateChanged event to get updates on the process.
 *
 * @param pid Unique ID
 * @param completion SPICompletionTxResult
 */
- (void)initiateSettleTx:(NSString *)pid completion:(SPICompletionTxResult)completion;

@end
