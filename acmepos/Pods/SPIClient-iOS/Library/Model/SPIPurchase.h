//
//  SPIPurchase.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"

@class SPIMessage;

@interface SPIPurchaseRequest : NSObject
@property (nonatomic, readonly, copy) NSString *purchaseId;
@property (nonatomic, readonly) NSInteger      amountCents;

- (instancetype)initWithPurchaseId:(NSString *)purchaseId
                       amountCents:(NSInteger)amountCents;

- (SPIMessage *)toMessage;
@end

@interface SPIPurchaseResponse : NSObject
@property (nonatomic, readonly) BOOL               isSuccess;
@property (nonatomic, readonly, copy) NSString     *requestid;
@property (nonatomic, readonly, copy) NSString     *schemeName;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getRRN;

- (NSString *)getCustomerReceipt;

- (NSString *)getResponseText;

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute;

- (NSString *)hostResponseText;

@end

@interface SPICancelTransactionRequest : NSObject
- (SPIMessage *)toMessage;
@end

@interface SPIGetLastTransactionRequest : NSObject
- (SPIMessage *)toMessage;
@end

@interface SPIGetLastTransactionResponse : NSObject
@property (nonatomic, strong) SPIMessage       *message;
@property (nonatomic, copy, readonly) NSString *bankDateTimeString;
@property (nonatomic, copy, readonly) NSDate   *bankDate;
@property (nonatomic) SPIMessageSuccessState   successState;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (BOOL)wasRetrievedSuccessfully;

- (BOOL)wasSuccessfulTx;
- (BOOL)wasOperationInProgressError;

- (NSString *)getTxType;

- (NSString *)getSchemeName;

- (NSInteger)getAmount;

- (NSInteger)getTransactionAmount;

- (NSString *)getRRN;

- (NSString *)getResponseValue:(NSString *)attribute;

- (void)copyMerchantReceiptToCustomerReceipt;

@end

@interface SPIRefundRequest : NSObject
@property (nonatomic, readonly, copy) NSString *refundId;
@property (nonatomic, readonly) NSInteger      amountCents;

- (instancetype)initWithRefundId:(NSString *)refundId amountCents:(NSInteger)amountCents;

- (SPIMessage *)toMessage;
@end

@interface SPIRefundResponse : NSObject
@property (nonatomic, readonly, copy) NSString     *requestId;
@property (nonatomic, readonly) BOOL               isSuccess;
@property (nonatomic, readonly, copy) NSString     *schemeName;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getRRN;

- (NSString *)getCustomerReceipt;

- (NSString *)getMerchantReceipt;

- (NSString *)getResponseText;

- (NSString *)getResponseValue:(NSString *)attribute;
@end

@interface SPISignatureRequired : NSObject
@property (nonatomic, readonly, copy) NSString     *requestId;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

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
