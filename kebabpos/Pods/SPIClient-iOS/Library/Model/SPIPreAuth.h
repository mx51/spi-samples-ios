//
//  SPIPreAuth.h
//  SPIClient-iOS
//
//  Created by Amir Kamali on 4/6/18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"
#import "SPITransaction.h"

extern NSString *const SPIAccountVerifyRequestKey;
extern NSString *const SPIAccountVerifyResponseKey;
extern NSString *const SPIPreauthOpenRequestKey;
extern NSString *const SPIPreauthOpenResponseKey;
extern NSString *const SPIPreauthTopupRequestKey;
extern NSString *const SPIPreauthTopupResponseKey;
extern NSString *const SPIPreauthExtendRequestKey;
extern NSString *const SPIPreauthExtendResponseKey;
extern NSString *const SPIPreauthPartialCancellationRequestKey;
extern NSString *const SPIPreauthPartialCancellationResponseKey;
extern NSString *const SPIPreauthCancellationRequestKey;
extern NSString *const SPIPreauthCancellationResponseKey;
extern NSString *const SPIPreauthCompleteRequestKey;
extern NSString *const SPIPreauthCompleteResponseKey;

@class SPIClient;

typedef void (^SPICompletionTxResult)(SPIInitiateTxResult *result);

@interface SPIPreAuth : NSObject

@property (nonatomic, strong) NSObject *txLock;

- (instancetype)init:(SPIClient *)client queue:(dispatch_queue_t)queue;

- (void)initiateAccountVerifyTx:(NSString *)posRefId
                     completion:(SPICompletionTxResult)completion;

- (void)initiateOpenTx:(NSString *)posRefId
           amountCents:(NSInteger)amountCents
            completion:(SPICompletionTxResult)completion;

- (void)initiateOpenTx:(NSString *)posRefId
           amountCents:(NSInteger)amountCents
               options:(SPITransactionOptions *)options
            completion:(SPICompletionTxResult)completion;

- (void)initiateTopupTx:(NSString *)posRefId
              preauthId:(NSString *)preauthId
            amountCents:(NSInteger)amountCents
             completion:(SPICompletionTxResult)completion;

- (void)initiateTopupTx:(NSString *)posRefId
              preauthId:(NSString *)preauthId
            amountCents:(NSInteger)amountCents
                options:(SPITransactionOptions *)options
             completion:(SPICompletionTxResult)completion;

- (void)initiatePartialCancellationTx:(NSString *)posRefId
                            preauthId:(NSString *)preauthId
                          amountCents:(NSInteger)amountCents
                           completion:(SPICompletionTxResult)completion;

- (void)initiatePartialCancellationTx:(NSString *)posRefId
                            preauthId:(NSString *)preauthId
                          amountCents:(NSInteger)amountCents
                              options:(SPITransactionOptions *)options
                           completion:(SPICompletionTxResult)completion;

- (void)initiateExtendTx:(NSString *)posRefId
               preauthId:(NSString *)preauthId
              completion:(SPICompletionTxResult)completion;

- (void)initiateExtendTx:(NSString *)posRefId
               preauthId:(NSString *)preauthId
                 options:(SPITransactionOptions *)options
              completion:(SPICompletionTxResult)completion;

- (void)initiateCompletionTx:(NSString *)posRefId
                   preauthId:(NSString *)preauthId
                 amountCents:(NSInteger)amountCents
                  completion:(SPICompletionTxResult)completion;

- (void)initiateCompletionTx:(NSString *)posRefId
                   preauthId:(NSString *)preauthId
                 amountCents:(NSInteger)amountCents
             surchargeAmount:(NSInteger)surchargeAmount
                  completion:(SPICompletionTxResult)completion;

- (void)initiateCompletionTx:(NSString *)posRefId
                   preauthId:(NSString *)preauthId
                 amountCents:(NSInteger)amountCents
             surchargeAmount:(NSInteger)surchargeAmount
                     options:(SPITransactionOptions *)options
                  completion:(SPICompletionTxResult)completion;

- (void)initiateCancelTx:(NSString *)posRefId
               preauthId:(NSString *)preauthId
              completion:(SPICompletionTxResult)completion;

- (void)initiateCancelTx:(NSString *)posRefId
               preauthId:(NSString *)preauthId
                 options:(SPITransactionOptions *)options
              completion:(SPICompletionTxResult)completion;

- (void)_handlePreauthMessage:(SPIMessage *)m;

- (BOOL)isPreauthEvent:(NSString *)eventName;

@end

@interface SPIAccountVerifyRequest : NSObject

@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, retain) SPIConfig *config;

- (instancetype)initWithPosRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIAccountVerifyResponse : NSObject

@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly, copy) SPIPurchaseResponse *details;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage: (SPIMessage *)message;

@end

@interface SPIPreauthOpenRequest : NSObject

@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly) NSInteger preauthAmount;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithAmountCents:(NSInteger)amountCents posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIPreauthTopupRequest : NSObject

@property (nonatomic, readonly, copy) NSString *preauthId;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly) NSInteger topupAmount;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithPreauthID:(NSString *)preauthID topupAmount:(NSInteger)topupAmount posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIPreauthPartialCancellationRequest : NSObject

@property (nonatomic, readonly, copy) NSString *preauthId;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly) NSInteger partialCancellationAmount;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithPreauthID:(NSString *)preauthID partialCancellationAmount:(NSInteger)partialCancellationAmount posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIPreauthExtendRequest : NSObject

@property (nonatomic, readonly, copy) NSString *preauthId;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithPreauthID:(NSString *)preauthID posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIPreauthCancelRequest : NSObject

@property (nonatomic, readonly, copy) NSString *preauthId;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithPreauthID:(NSString *)preauthID posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIPreauthCompletionRequest : NSObject

@property (nonatomic, readonly, copy) NSString *preauthId;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly) NSInteger completionAmount;
@property (nonatomic) NSInteger surchargeAmount;
@property (nonatomic, retain) SPIConfig *config;
@property (nonatomic, retain) SPITransactionOptions *options;

- (instancetype)initWithPreauthID:(NSString *)preauthID completionAmount:(NSInteger)completionAmount posRefId:(NSString *)posRefId;

- (SPIMessage *)toMessage;

@end

@interface SPIPreauthResponse : NSObject

@property (nonatomic, readonly, copy) NSString *preauthId;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, readonly, copy) SPIPurchaseResponse *details;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSInteger)getBalanceAmount;

- (NSInteger)getPreviousBalanceAmount;

- (NSInteger)getCompletionAmount;

- (NSInteger)getSurchargeAmountForPreauthCompletion;

- (NSString *)getCustomerReceipt;

- (NSString *)getMerchantReceipt;

- (BOOL)wasMerchantReceiptPrinted;

- (BOOL)wasCustomerReceiptPrinted;

@end
