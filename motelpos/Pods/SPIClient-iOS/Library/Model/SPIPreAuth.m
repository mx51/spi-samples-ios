//
//  SPIPreAuth.m
//  SPIClient-iOS
//
//  Created by Amir Kamali on 4/6/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIClient.h"
#import "SPIClient+Internal.h"
#import "SPILogger.h"
#import "SPIPreAuth.h"
#import "SPIRequestIdHelper.h"

NSString *const SPIAccountVerifyRequestKey = @"account_verify";
NSString *const SPIAccountVerifyResponseKey = @"account_verify_response";
NSString *const SPIPreauthOpenRequestKey = @"preauth";
NSString *const SPIPreauthOpenResponseKey = @"preauth_response";
NSString *const SPIPreauthTopupRequestKey = @"preauth_topup";
NSString *const SPIPreauthTopupResponseKey = @"preauth_topup_response";
NSString *const SPIPreauthExtendRequestKey = @"preauth_extend";
NSString *const SPIPreauthExtendResponseKey = @"preauth_extend_response";
NSString *const SPIPreauthPartialCancellationRequestKey = @"preauth_partial_cancellation";
NSString *const SPIPreauthPartialCancellationResponseKey = @"preauth_partial_cancellation_response";
NSString *const SPIPreauthCancellationRequestKey = @"preauth_cancellation";
NSString *const SPIPreauthCancellationResponseKey = @"preauth_cancellation_response";
NSString *const SPIPreauthCompleteRequestKey = @"completion";
NSString *const SPIPreauthCompleteResponseKey = @"completion_response";

@interface SPIPreAuth () <SPIDelegate> {
    dispatch_queue_t _queue;
    SPIClient *_client;
}

@end

@implementation SPIPreAuth

- (instancetype)init:(SPIClient *)client queue:(dispatch_queue_t)queue {
    _client = client;
    _queue = queue;
    _txLock = [[NSObject alloc] init];
    
    return self;
}

#pragma mark - Delegate

- (void)callDelegate:(void (^)(id<SPIDelegate>))block {
    if (_client.delegate != nil) {
        __weak __typeof(&*_client) weakSelf = _client;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(weakSelf.delegate);
        });
    }
}

- (void)transactionFlowStateChanged {
    [self callDelegate:^(id<SPIDelegate> delegate) {
        [delegate spi:self->_client transactionFlowStateChanged:self->_client.state.copy];
    }];
}

#pragma mark - Transactions

- (void)initiateAccountVerifyTx:(NSString *)posRefId
                     completion:(SPICompletionTxResult)completion {
    
    SPIAccountVerifyRequest *accountVerifyRequest = [[SPIAccountVerifyRequest alloc] initWithPosRefId:posRefId];
    
    accountVerifyRequest.config = _client.config;
    
    SPIMessage *accountVerifyMsg = [accountVerifyRequest toMessage];
    
    SPITransactionFlowState *tfs = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                           type:SPITransactionTypeAccountVerify
                                                                    amountCents:0
                                                                        message:accountVerifyMsg
                                                                            msg:@"Waiting for EFTPOS connection to make account verify request"];
    
    NSString *message = @"Asked EFTPOS to verify account";
    [self _initiatePreauthTx:tfs message:message completion:completion];
}

- (void)initiateOpenTx:(NSString *)posRefId
           amountCents:(NSInteger)amountCents
            completion:(SPICompletionTxResult)completion {
    
    SPIPreauthOpenRequest *preauthRequest = [[SPIPreauthOpenRequest alloc] initWithAmountCents:amountCents posRefId:posRefId];
    
    preauthRequest.config = _client.config;
    
    SPIMessage *preauthMsg = [preauthRequest toMessage];
    
    SPITransactionFlowState *tfs = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                           type:SPITransactionTypePreAuth
                                                                    amountCents:amountCents
                                                                        message:preauthMsg
                                                                            msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make preauth request for %.2f", ((float)amountCents / 100.0)]];
    
    NSString *message = [NSString stringWithFormat:@"Asked EFTPOS to create preauth for %.2f", ((float)amountCents / 100.0)];
    [self _initiatePreauthTx:tfs message:message completion:completion];
}

- (void)initiateTopupTx:(NSString *)posRefId
              preauthId:(NSString *)preauthId
            amountCents:(NSInteger)amountCents
             completion:(SPICompletionTxResult)completion {
    
    SPIPreauthTopupRequest *preauthRequest = [[SPIPreauthTopupRequest alloc] initWithPreauthID:preauthId topupAmount:amountCents posRefId:posRefId];
    
    preauthRequest.config = _client.config;
    
    SPIMessage *preauthMsg = [preauthRequest toMessage];
    
    SPITransactionFlowState *tfs = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                           type:SPITransactionTypePreAuth
                                                                    amountCents:amountCents
                                                                        message:preauthMsg
                                                                            msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make preauth topup request for %.2f", ((float)amountCents / 100.0)]];
    
    NSString *message = [NSString stringWithFormat:@"Asked EFTPOS to make preauth request topup for %.2f", ((float)amountCents / 100.0)];
    [self _initiatePreauthTx:tfs message:message completion:completion];
}

- (void)initiatePartialCancellationTx:(NSString *)posRefId
                            preauthId:(NSString *)preauthId
                          amountCents:(NSInteger)amountCents
                           completion:(SPICompletionTxResult)completion {
    SPIPreauthPartialCancellationRequest *preauthRequest = [[SPIPreauthPartialCancellationRequest alloc] initWithPreauthID:preauthId partialCancellationAmount:amountCents posRefId:posRefId];
    
    preauthRequest.config = _client.config;
    
    SPIMessage *preauthMsg = [preauthRequest toMessage];
    
    SPITransactionFlowState *tfs = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                           type:SPITransactionTypePreAuth
                                                                    amountCents:amountCents
                                                                        message:preauthMsg
                                                                            msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make preauth partial cancellation request for %.2f", ((float)amountCents / 100.0)]];
    
    NSString *message = [NSString stringWithFormat:@"Asked EFTPOS to make preauth partial cancellation for %.2f", ((float)amountCents / 100.0)];
    [self _initiatePreauthTx:tfs message:message completion:completion];
}

- (void)initiateExtendTx:(NSString *)posRefId
               preauthId:(NSString *)preauthId
              completion:(SPICompletionTxResult)completion {
    SPIPreauthExtendRequest *preauthRequest = [[SPIPreauthExtendRequest alloc] initWithPreauthID:preauthId posRefId:posRefId];
    
    preauthRequest.config = _client.config;
    
    SPIMessage *preauthMsg = [preauthRequest toMessage];
    
    SPITransactionFlowState *tfs = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                           type:SPITransactionTypePreAuth
                                                                    amountCents:0
                                                                        message:preauthMsg
                                                                            msg:@"Waiting for EFTPOS connection to make preauth Extend request"];
    
    NSString *message = @"Asked EFTPOS to make preauth Extend request";
    [self _initiatePreauthTx:tfs message:message completion:completion];
}

- (void)initiateCompletionTx:(NSString *)posRefId
                   preauthId:(NSString *)preauthId
                 amountCents:(NSInteger)amountCents
                  completion:(SPICompletionTxResult)completion {
    [self initiateCompletionTx:posRefId preauthId:preauthId amountCents:amountCents surchargeAmount:0 completion:completion];
}

- (void)initiateCompletionTx:(NSString *)posRefId
                   preauthId:(NSString *)preauthId
                 amountCents:(NSInteger)amountCents
             surchargeAmount:(NSInteger)surchargeAmount
                  completion:(SPICompletionTxResult)completion {
    SPIPreauthCompletionRequest *preauthRequest = [[SPIPreauthCompletionRequest alloc] initWithPreauthID:preauthId completionAmount:amountCents posRefId:posRefId];
    
    preauthRequest.surchargeAmount = surchargeAmount;
    preauthRequest.config = _client.config;
    
    SPIMessage *preauthMsg = [preauthRequest toMessage];
    
    SPITransactionFlowState *tfs = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                           type:SPITransactionTypePreAuth
                                                                    amountCents:amountCents
                                                                        message:preauthMsg
                                                                            msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make preauth completion request for $%.2f surcharge amount: $%.2f", ((float)amountCents / 100.0), ((float)surchargeAmount / 100.0)]];
    
    NSString *message = [NSString stringWithFormat:@"Asked EFTPOS to make preauth completion for %.2f surcharge amount: $%.2f", ((float)amountCents / 100.0), ((float)surchargeAmount / 100.0)];
    [self _initiatePreauthTx:tfs message:message completion:completion];
}

- (void)initiateCancelTx:(NSString *)posRefId
               preauthId:(NSString *)preauthId
              completion:(SPICompletionTxResult)completion {
    SPIPreauthCancelRequest *preauthRequest = [[SPIPreauthCancelRequest alloc] initWithPreauthID:preauthId posRefId:posRefId];
    
    preauthRequest.config = _client.config;
    
    SPIMessage *preauthMsg = [preauthRequest toMessage];
    
    SPITransactionFlowState *tfs = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                           type:SPITransactionTypePreAuth
                                                                    amountCents:0
                                                                        message:preauthMsg
                                                                            msg:@"Waiting for EFTPOS connection to make preauth cancellation request"];
    
    NSString *message = @"Asked EFTPOS to make preauth cancellation request";
    [self _initiatePreauthTx:tfs message:message completion:completion];
}

-(void)_initiatePreauthTx:(SPITransactionFlowState *)tfs
                  message:(NSString *)message
               completion:(SPICompletionTxResult)completion {
    
    if (_client.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(_queue, ^{
        @synchronized(weakSelf.txLock) {
            if (self->_client.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            self->_client.state.flow = SPIFlowTransaction;
            self->_client.state.txFlowState = tfs;
            
            if ([self->_client send:tfs.request]) {
                [self->_client.state.txFlowState sent:message];
            }
        }
        
        [self transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Preauth initiated"]);
    });
}

#pragma mark - Transaction Management

- (void)_handlePreauthMessage:(SPIMessage *)m {
    NSString *eventName = m.eventName;
    
    if ([eventName isEqualToString:SPIAccountVerifyResponseKey]) {
        [self _handleAccountVerifyResponse:m];
    } else if ([eventName isEqualToString:SPIPreauthOpenResponseKey] ||
               [eventName isEqualToString:SPIPreauthTopupResponseKey] ||
               [eventName isEqualToString:SPIPreauthPartialCancellationResponseKey] ||
               [eventName isEqualToString:SPIPreauthExtendResponseKey] ||
               [eventName isEqualToString:SPIPreauthCompleteResponseKey] ||
               [eventName isEqualToString:SPIPreauthCancellationResponseKey]) {
        [self _handlePreauthResponse:m];
    } else {
        SPILog(@"I don't understand Preauth event:'%@', %@. Perhaps I have not implemented it yet.", eventName, m.data);
    }
}

-(void)_handleAccountVerifyResponse:(SPIMessage *)m {
    @synchronized(self.txLock) {
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (_client.state.flow != SPIFlowTransaction || _client.state.txFlowState.isFinished || ![_client.state.txFlowState.posRefId isEqualToString:incomingPosRefId]) {
            SPILog(@"Received Account Verify response but I was not waiting for one. Incoming Pos Ref ID: %@", incomingPosRefId);
            return;
        }
        
        [_client.state.txFlowState completed:m.successState
                                    response:m msg:@"Account Verify Transaction Ended."];
    }
    
    [self transactionFlowStateChanged];
}

-(void)_handlePreauthResponse:(SPIMessage *)m {
    @synchronized(self.txLock) {
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (_client.state.flow != SPIFlowTransaction || _client.state.txFlowState.isFinished || ![_client.state.txFlowState.posRefId isEqualToString:incomingPosRefId]) {
            SPILog(@"Received Preauth response but I was not waiting for one. Incoming Pos Ref ID: %@", incomingPosRefId);
            return;
        }
        
        [_client.state.txFlowState completed:m.successState
                                    response:m msg:@"Preauth Transaction Ended."];
    }
    
    [self transactionFlowStateChanged];
}

- (BOOL)isPreauthEvent:(NSString *)eventName {
    return [eventName hasPrefix:@"preauth"] ||
    [eventName isEqualToString:SPIPreauthCompleteResponseKey] ||
    [eventName isEqualToString:SPIPreauthCompleteRequestKey] ||
    [eventName isEqualToString:SPIAccountVerifyRequestKey] ||
    [eventName isEqualToString:SPIAccountVerifyResponseKey];
}

@end

#pragma mark -

@implementation SPIAccountVerifyRequest : NSObject

- (instancetype)initWithPosRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _posRefId = posRefId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prav"]
                                       eventName:SPIAccountVerifyRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIAccountVerifyResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _details = [[SPIPurchaseResponse alloc] initWithMessage:message];
        _posRefId = _details.posRefId;
        _message = message;
    }
    
    return self;
}

@end

@implementation SPIPreauthOpenRequest : NSObject

- (instancetype)initWithAmountCents:(NSInteger)amountCents
                           posRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _posRefId = posRefId;
        _preauthAmount = amountCents;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:[NSNumber numberWithInteger:_preauthAmount] forKey:@"preauth_amount"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prac"]
                                       eventName:SPIPreauthOpenRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIPreauthTopupRequest : NSObject

- (instancetype)initWithPreauthID:(NSString *)preauthID
                      topupAmount:(NSInteger)topupAmount
                         posRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _preauthId = preauthID;
        _topupAmount = topupAmount;
        _posRefId = posRefId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:_preauthId forKey:@"preauth_id"];
    [data setValue:[NSNumber numberWithInteger:_topupAmount] forKey:@"topup_amount"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prtu"]
                                       eventName:SPIPreauthTopupRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIPreauthPartialCancellationRequest : NSObject

- (instancetype)initWithPreauthID:(NSString *)preauthID
        partialCancellationAmount:(NSInteger)partialCancellationAmount
                         posRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _preauthId = preauthID;
        _partialCancellationAmount = partialCancellationAmount;
        _posRefId = posRefId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:_preauthId forKey:@"preauth_id"];
    [data setValue:[NSNumber numberWithInteger:_partialCancellationAmount] forKey:@"preauth_cancel_amount"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prpc"]
                                       eventName:SPIPreauthPartialCancellationRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIPreauthExtendRequest : NSObject

- (instancetype)initWithPreauthID:(NSString *)preauthID
                         posRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _preauthId = preauthID;
        _posRefId = posRefId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:_preauthId forKey:@"preauth_id"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prext"]
                                       eventName:SPIPreauthExtendRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIPreauthCancelRequest : NSObject

- (instancetype)initWithPreauthID:(NSString *)preauthID
                         posRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _preauthId = preauthID;
        _posRefId = posRefId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:_preauthId forKey:@"preauth_id"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prac"]
                                       eventName:SPIPreauthCancellationRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIPreauthCompletionRequest : NSObject

- (instancetype)initWithPreauthID:(NSString *)preauthID
                 completionAmount:(NSInteger)completionAmount
                         posRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _preauthId = preauthID;
        _completionAmount = completionAmount;
        _posRefId = posRefId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:_preauthId forKey:@"preauth_id"];
    [data setValue:[NSNumber numberWithInteger:_completionAmount] forKey:@"completion_amount"];
    [data setValue:[NSNumber numberWithInteger:_surchargeAmount] forKey:@"surcharge_amount"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prac"]
                                       eventName:SPIPreauthCompleteRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIPreauthResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _preauthId = [_message getDataStringValue:@"preauth_id"];
        _details = [[SPIPurchaseResponse alloc] initWithMessage:message];
        _posRefId = _details.posRefId;
        _message = message;
    }
    
    return self;
}

- (NSInteger)getBalanceAmount {
    NSString *txType = [_message getDataStringValue:@"transaction_type"];
    if ([txType  isEqual: @"PRE-AUTH"]) {
        return [_message getDataIntegerValue:@"preauth_amount"];
    } else if ([txType  isEqual: @"TOPUP"]) {
        return [_message getDataIntegerValue:@"balance_amount"];
    } else if ([txType  isEqual: @"CANCEL"]) {
        return [_message getDataIntegerValue:@"balance_amount"];
    } else if ([txType  isEqual: @"PRE-AUTH EXT"]) {
        return [_message getDataIntegerValue:@"balance_amount"];
    } else if ([txType  isEqual: @"PCOMP"]) {
        return 0;
    } else if ([txType  isEqual: @"PRE-AUTH CANCEL"]) {
        return 0;
    } else {
        return 0;
    }
}

- (NSInteger)getPreviousBalanceAmount {
    NSString *txType = [_message getDataStringValue:@"transaction_type"];
    if ([txType  isEqual: @"PRE-AUTH"]) {
        return 0;
    } else if ([txType  isEqual: @"TOPUP"]) {
        return [_message getDataIntegerValue:@"existing_preauth_amount"];
    } else if ([txType  isEqual: @"CANCEL"]) {
        return [_message getDataIntegerValue:@"existing_preauth_amount"];
    } else if ([txType  isEqual: @"PRE-AUTH EXT"]) {
        return [_message getDataIntegerValue:@"existing_preauth_amount"];
    } else if ([txType  isEqual: @"PCOMP"]) {
        // THIS IS TECHNICALLY NOT CORRECT WHEN COMPLETION HAPPENS FOR A PARTIAL AMOUNT.
        // BUT UNFORTUNATELY, THIS RESPONSE DOES NOT CONTAIN "existing_preauth_amount".
        // SO "completion_amount" IS THE CLOSEST WE HAVE.
        return [_message getDataIntegerValue:@"completion_amount"];
    } else if ([txType  isEqual: @"PRE-AUTH CANCEL"]) {
        return [_message getDataIntegerValue:@"preauth_amount"];;
    } else {
        return 0;
    }
}

- (NSInteger)getCompletionAmount {
    NSString *txType = [_message getDataStringValue:@"transaction_type"];
    if ([txType  isEqual: @"PCOMP"]) {
        return [_message getDataIntegerValue:@"completion_amount"];
    } else {
        return 0;
    }
}

- (NSInteger)getSurchargeAmountForPreauthCompletion {
    NSString *txType = [_message getDataStringValue:@"transaction_type"];
    if ([txType  isEqual: @"PCOMP"]) {
        return [_message getDataIntegerValue:@"surcharge_amount"];
    } else {
        return 0;
    }
}

@end
