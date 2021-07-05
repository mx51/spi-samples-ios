//
//  SPITransaction.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"

@class SPIMessage;
@class SPIConfig;
@class SPITransactionOptions;

@interface SPIPurchaseRequest : NSObject

@property (nonatomic, readonly, copy) NSString *purchaseId DEPRECATED_MSG_ATTRIBUTE("Use posRefId instead.");
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly) NSInteger amountCents DEPRECATED_MSG_ATTRIBUTE("Use purchaseAmount instead.");
@property (nonatomic, readonly) NSInteger purchaseAmount;
@property (nonatomic) NSInteger tipAmount;
@property (nonatomic) NSInteger cashoutAmount;
@property (nonatomic) BOOL promptForCashout;
@property (nonatomic) NSInteger surchargeAmount;

@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithAmountCents:(NSInteger)amountCents
                           posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;
- (NSString *)amountSummary;

@end

@interface SPIPurchaseResponse : NSObject

@property (nonatomic, readonly) BOOL isSuccess;
@property (nonatomic, readonly, copy) NSString *requestid;
@property (nonatomic, readonly, copy) NSString *schemeName;
@property (nonatomic, retain) NSString *posRefId;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getRRN;

- (NSInteger)getPurchaseAmount;

- (NSInteger)getTipAmount;

- (NSInteger)getSurchargeAmount;

- (NSInteger)getCashoutAmount;

- (NSInteger)getBankNonCashAmount;

- (NSInteger)getBankCashAmount;

- (NSString *)getCustomerReceipt;

- (NSString *)getMerchantReceipt;

- (NSString *)getResponseText;

- (NSDictionary *)toPaymentSummary;

- (NSDate *)getSettlementDate;

- (NSString *)getResponseCode;

- (NSString *)getTerminalReferenceId;

- (NSString *)getCardEntry;

- (NSString *)getAccountType;

- (NSString *)getAuthCode;

- (NSString *)getBankDate;

- (NSString *)getBankTime;

- (NSString *)getMaskedPan;

- (NSString *)getTerminalId;

- (BOOL)wasMerchantReceiptPrinted;

- (BOOL)wasCustomerReceiptPrinted;

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute;

@end

@interface SPICancelTransactionRequest : NSObject

- (SPIMessage *)toMessage;

@end

@interface SPICancelTransactionResponse : NSObject

@property (nonatomic, readonly, strong) SPIMessage *message;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly) BOOL isSuccess;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getErrorReason;

- (NSString *)getErrorDetail;

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute;

- (BOOL)wasTxnPastPointOfNoReturn;

@end

@interface SPIGetLastTransactionRequest : NSObject

- (SPIMessage *)toMessage;

@end

@interface SPIGetLastTransactionResponse : NSObject

@property (nonatomic, strong) SPIMessage *message;
@property (nonatomic, copy, readonly) NSString *bankDateTimeString;
@property (nonatomic) SPIMessageSuccessState successState;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (BOOL)wasTimeOutOfSyncError;

- (BOOL)wasRetrievedSuccessfully;

- (BOOL)wasOperationInProgressError;

- (BOOL)isWaitingForSignatureResponse;

- (BOOL)isWaitingForAuthCode;

- (BOOL)isStillInProgress:(NSString *)posRefId;

- (SPIMessageSuccessState)getSuccessState;

- (BOOL)wasSuccessfulTx;

- (NSString *)getTxType;

- (NSString *)getPosRefId;

- (NSInteger)getBankNonCashAmount;

- (NSString *)getSchemeApp DEPRECATED_MSG_ATTRIBUTE("Should not need to look at this in a GLT response");

- (NSString *)getSchemeName DEPRECATED_MSG_ATTRIBUTE("Should not need to look at this in a GLT response");

- (NSInteger)getAmount DEPRECATED_MSG_ATTRIBUTE("Should not need to look at this in a GLT response");

- (NSInteger)getTransactionAmount DEPRECATED_MSG_ATTRIBUTE("Should not need to look at this in a GLT response");

- (NSString *)getBankDateTimeString;

- (NSString *)getRRN DEPRECATED_MSG_ATTRIBUTE("Should not need to look at this in a GLT response");

- (NSString *)getResponseText;

- (NSString *)getResponseCode;

- (void)copyMerchantReceiptToCustomerReceipt;

@end

@interface SPIRefundRequest : NSObject

@property (nonatomic, readonly, copy) NSString *refundId DEPRECATED_MSG_ATTRIBUTE("Use posRefId instead.");
@property (nonatomic, readonly) NSInteger amountCents;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, assign) BOOL suppressMerchantPassword;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithPosRefId:(NSString *)posRefId
                     amountCents:(NSInteger)amountCents;

- (SPIMessage *)toMessage;

@end

@interface SPIRefundResponse : NSObject

@property (nonatomic, readonly, copy) NSString *requestId;
@property (nonatomic, readonly) BOOL isSuccess;
@property (nonatomic, readonly, copy) NSString *schemeName;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSInteger)getRefundAmount;

- (NSString *)getRRN;

- (NSString *)getCustomerReceipt;

- (NSString *)getMerchantReceipt;

- (NSDate *)getSettlementDate;

- (NSString *)getResponseText;

- (NSString *)getResponseCode;

- (NSString *)getTerminalReferenceId;

- (NSString *)getCardEntry;

- (NSString *)getAccountType;

- (NSString *)GetAuthCode;

- (NSString *)getBankDate;

- (NSString *)getBankTime;

- (NSString *)getMaskedPan;

- (NSString *)getTerminalId;

- (BOOL)wasMerchantReceiptPrinted;

- (BOOL)wasCustomerReceiptPrinted;

- (NSString *)getResponseValue:(NSString *)attribute;

@end

@interface SPISignatureRequired : NSObject

@property (nonatomic, readonly, copy) NSString *requestId;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (instancetype)initWithPosRefId:(NSString *)posRefId
                       requestId:(NSString *)requestId
                   receiptToSign:(NSString *)receiptToSign;

- (NSString *)getMerchantReceipt;

@end

@interface SPISignatureDecline : NSObject

@property (nonatomic, readonly, copy) NSString *signatureRequiredRequestId;

- (instancetype)initWithSignatureRequiredRequestId:(NSString *)signatureRequiredRequestId;

- (SPIMessage *)toMessage;

@end

@interface SPISignatureAccept : NSObject

@property (nonatomic, readonly, copy) NSString *signatureRequiredRequestId;

- (instancetype)initWithSignatureRequiredRequestId:(NSString *)signatureRequiredRequestId;

- (SPIMessage *)toMessage;

@end

@interface SPIMotoPurchaseRequest : NSObject

@property (nonatomic, readonly) NSInteger purchaseAmount;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic) NSInteger surchargeAmount;
@property (nonatomic, assign) BOOL suppressMerchantPassword;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithAmountCents:(NSInteger)amountCents
                           posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIMotoPurchaseResponse : NSObject

@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly, copy) SPIPurchaseResponse *purchaseResponse;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end

@interface SPIPhoneForAuthRequired : NSObject

@property (nonatomic, readonly, copy) NSString *requestId;
@property (nonatomic, readonly, copy) NSString *posRefId;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (instancetype)initWithPosRefId:(NSString *)posRefId
                       requestId:(NSString *)requestId
                     phoneNumber:(NSString *)phoneNumber
                      merchantId:(NSString *)merchantId;

- (NSString *)getPhoneNumber;

- (NSString *)getMerchantId;

@end

@interface SPIAuthCodeAdvice : NSObject

@property (nonatomic, readonly, copy) NSString *authCode;
@property (nonatomic, readonly, copy) NSString *posRefId;

- (instancetype)initWithPosRefId:(NSString *)posRefId
                        authCode:(NSString *)authCode;

- (SPIMessage *)toMessage;

@end

@interface SPIUpdateMessage : NSObject

@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly, copy) NSString *displayMessageCode;
@property (nonatomic, readonly, copy) NSString *displayMessageText;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end
