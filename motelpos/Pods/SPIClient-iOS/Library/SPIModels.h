//
//  SPIModels.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2018-01-13.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPIMessage.h"
#import "SPITransaction.h"

/**
 Represents the 3 pairing statuses that the SPI instance can be in.
 
 - SPIStatusUnpaired: Unpaired
 - SPIStatusPairedConnecting: Paired but trying to establish a connection
 - SPIStatusPairedConnected: Paired and Connected
 */
typedef NS_ENUM(NSUInteger, SPIStatus) {
    SPIStatusUnpaired,
    SPIStatusPairedConnecting,
    SPIStatusPairedConnected,
};

/**
 The SPI instance can be in one of these flows at any point in time.
 
 - SPIFlowIdle: Not in any of the other states.
 - SPIFlowPairing: Currently going through the pairing process flow. Happens during the unpaired status.
 - SPIFlowTransaction: Currently going through the transaction process flow. Cannot happen in the unpaired status.
 */
typedef NS_ENUM(NSUInteger, SPIFlow) {
    SPIFlowIdle,
    SPIFlowPairing,
    SPIFlowTransaction,
};

/**
 Types of supported transactions.

 - SPITransactionTypePurchase: Purchase.
 - SPITransactionTypeRefund: Refund.
 - SPITransactionTypeCashoutOnly: Cashout-only.
 - SPITransactionTypeMOTO: Mail Order/Telephone Order.
 - SPITransactionTypeSettle: Settlement.
 - SPITransactionTypeSettleEnquiry: Settlement enquiry.
 - SPITransactionTypeGetLastTransaction: Get last transaction.
 - SPITransactionTypePreAuth: Pre-auth.
 - SPITransactionTypeAccountVerify: Account verification.
 */
typedef NS_ENUM(NSUInteger, SPITransactionType) {
    SPITransactionTypePurchase,
    SPITransactionTypeRefund,
    SPITransactionTypeCashoutOnly,
    SPITransactionTypeMOTO,
    SPITransactionTypeSettle,
    SPITransactionTypeSettleEnquiry,
    SPITransactionTypeGetLastTransaction,
    SPITransactionTypePreAuth,
    SPITransactionTypeAccountVerify,
};

/**
 Represents the pairing flow state during the pairing process.
 */
@interface SPIPairingFlowState : NSObject <NSCopying>

/**
 Some text that can be displayed in the pairing process screen
 that indicates what the pairing process is up to.
 */
@property (nonatomic, copy) NSString *message;

/**
 This is the confirmation code for the pairing process.
 */
@property (nonatomic, copy) NSString *confirmationCode;

/**
 When true, it means that the EFTPOS is shoing the confirmation code,
 and your user needs to press YES or NO on the EFTPOS.
 */
@property (nonatomic, assign) BOOL isAwaitingCheckFromEftpos;

/**
 When true, you need to display the YES/NO buttons on you pairing screen
 for your user to confirm the code.
 */
@property (nonatomic, assign) BOOL isAwaitingCheckFromPos;

/**
 Indicates whether the pairing flow has finished its job.
 */
@property (nonatomic, assign) BOOL isFinished;

/**
 Indicates whether pairing was successful or not.
 */
@property (nonatomic, assign) BOOL isSuccessful;

@end

/**
 Used as a return in the InitiateTx methods to signify whether
 the transaction was initiated or not, and a reason to go with it.
 */
@interface SPIInitiateTxResult : NSObject

/**
 Text that gives reason for the Initiated flag, especially in case of false.
 */
@property (nonatomic, copy) NSString *message;

/**
 Whether the tx was initiated.
 When true, you can expect updated to your registered callback.
 When false, you can retry calling the InitiateX method.
 */
@property (nonatomic, assign) BOOL isInitiated;

- (instancetype)initWithTxResult:(BOOL)isInitiated message:(NSString *)message;

@end

@interface SPISubmitAuthCodeResult : NSObject

@property (nonatomic, assign) BOOL isValidFormat;

/**
 Text that gives reason for invalidity.
 */
@property (nonatomic, copy) NSString *message;

- (instancetype)initWithValidFormat:(BOOL)isValidFormat msg:(NSString *)message;

@end

/**
 Represents the state during a transaction flow.
 */
@interface SPITransactionFlowState : NSObject <NSCopying>

/**
 The ID given to this transaction
 */
@property (nonatomic, copy) NSString *tid __deprecated_msg("Use posRefId instead.");

@property (nonatomic, copy) NSString *posRefId;

/**
 Type of transaction, e.g. purchase, refund, settle.
 */
@property (nonatomic, assign) SPITransactionType type;

/**
 A text message to display on your transaction flow screen.
 */
@property (nonatomic, copy) NSString *displayMessage;

/**
 Amount in cents for this transaction.
 */
@property (nonatomic, assign) NSInteger amountCents;

/**
 Whether the request has been sent to the EFTPOS yet or not.
 In the PairedConnecting state, the transaction is initiated
 but the request is only sent once the connection is recovered.
 */
@property (nonatomic, assign) BOOL isRequestSent;

/**
 The time when the request was sent to the EFTPOS.
 */
@property (nonatomic, strong) NSDate *requestDate;

/**
 The time when we last asked for an update, including the original request at first.
 */
@property (nonatomic, strong) NSDate *lastStateRequestTime;

/**
 Whether we're currently attempting to cancel the transaction.
 */
@property (nonatomic, assign) BOOL isAttemptingToCancel;

/**
 When this flag is on, you need to display the dignature accept/decline buttons in your
 transaction flow screen.
 */
@property (nonatomic, assign) BOOL isAwaitingSignatureCheck;

/**
 When this flag is on, the library is awaiting Phone for Auth.
 */
@property (nonatomic, assign) BOOL isAwaitingPhoneForAuth;

/**
 Whether this transaction flow is over or not.
 */
@property (nonatomic, assign) BOOL isFinished;

/**
 The success state of this transaction. Starts off as Unknown.
 When finished, can be Success, Failed or Unknown.
 */
@property (nonatomic, assign) SPIMessageSuccessState successState;

/**
 The response at the end of the transaction. Might not be present in all edge cases.
 You can then turn this SPIMessage into the appropriate structure, such as PurchaseResponse, RefundResponse, etc.
 */
@property (nonatomic, strong) SPIMessage *response;

/**
 The message the we received from EFTPOS that told us that signature is required.
 */
@property (nonatomic, strong) SPISignatureRequired *signatureRequiredMessage;

/**
 The message the we received from EFTPOS that told us that Phone for Auth is required.
 */
@property (nonatomic, strong) SPIPhoneForAuthRequired *phoneForAuthRequiredMessage;

/**
 The time when the cancel attempt was made.
 */
@property (nonatomic, strong) NSDate *cancelAttemptTime;

/**
 The request message that we are sending/sent to the server.
 */
@property (nonatomic, strong) SPIMessage *request;

/**
 Whether we're currently waiting for a Get Last Transaction response to get an update.
 */
@property (nonatomic, assign) BOOL isAwaitingGltResponse;

/**
 The pos ref id  when Get Last Transaction response.
 */
@property (nonatomic, copy) NSString *gltResponsePosRefId;

- (instancetype)initWithTid:(NSString *)tid
                       type:(SPITransactionType)type
                amountCents:(NSInteger)amountCents
                    message:(SPIMessage *)message
                        msg:(NSString *)msg;

- (void)sent:(NSString *)msg;

- (void)cancelling:(NSString *)msg;

- (void)cancelFailed:(NSString *)msg;

- (void)callingGlt;

- (void)gotGltResponse;

- (void)failed:(SPIMessage *)response msg:(NSString *)msg;

- (void)signatureRequired:(SPISignatureRequired *)spiMessage msg:(NSString *)msg;

- (void)signatureResponded:(NSString *)msg;

- (void)phoneForAuthRequired:(SPIPhoneForAuthRequired *)spiMessage msg:(NSString *)msg;

- (void)authCodeSent:(NSString *)msg;

- (void)completed:(SPIMessageSuccessState)state response:(SPIMessage *)response msg:(NSString *)msg;

- (void)unknownCompleted:(NSString *)msg;

+ (NSString *)txTypeString:(SPITransactionType)type;

@end

/**
 Represents the state of SPI.
 */
@interface SPIState : NSObject <NSCopying>

/**
 The status of this SPI instance. Unpaired, PairedConnecting or PairedConnected.
 */
@property (nonatomic, assign) SPIStatus status;

/**
 The flow that this SPI instance is currently in.
 */
@property (nonatomic, assign) SPIFlow flow;

/**
 When flow is Pairing, this represents the state of the pairing process.
 */
@property (nonatomic, strong) SPIPairingFlowState *pairingFlowState;

/**
 When flow is Transaction, this represents the state of the transaction process.
 */
@property (nonatomic, strong) SPITransactionFlowState *txFlowState;

+ (NSString *)flowString:(SPIFlow)flow;

@end

/**
 Global configurations for operations.
 */
@interface SPIConfig : NSObject

@property (nonatomic) BOOL promptForCustomerCopyOnEftpos;
@property (nonatomic) BOOL signatureFlowOnEftpos;
@property (nonatomic) BOOL printMerchantCopy;

- (void)addReceiptConfig:(NSMutableDictionary *)data;

@end

/**
 Per-transaction options.
 */
@interface SPITransactionOptions : NSObject

@property (nonatomic, copy) NSString *customerReceiptHeader;
@property (nonatomic, copy) NSString *customerReceiptFooter;

@property (nonatomic, copy) NSString *merchantReceiptHeader;
@property (nonatomic, copy) NSString *merchantReceiptFooter;

- (void)addOptions:(NSMutableDictionary *)data;

@end
