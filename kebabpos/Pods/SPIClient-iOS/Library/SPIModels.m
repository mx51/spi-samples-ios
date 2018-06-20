//
//  SPIModels.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2018-01-13.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+Util.h"
#import "SPIModels.h"

@implementation SPIInitiateTxResult

- (instancetype)initWithTxResult:(BOOL)isInitiated message:(NSString *)message {
    
    self = [super init];
    
    if (self) {
        _isInitiated = isInitiated;
        _message = [message copy];
    }
    
    return self;
}

- (NSString *)description {
    return [self dynamicDescription];
}

@end

@implementation SPIPairingFlowState

- (id)copyWithZone:(NSZone *)zone {
    SPIPairingFlowState *state = [SPIPairingFlowState new];
    state.message = self.message;
    state.confirmationCode = self.confirmationCode;
    state.isAwaitingCheckFromEftpos = self.isAwaitingCheckFromEftpos;
    state.isAwaitingCheckFromPos = self.isAwaitingCheckFromPos;
    state.isFinished = self.isFinished;
    state.isSuccessful = self.isSuccessful;
    return state;
}

- (NSString *)description {
    return [self dynamicDescription];
}

@end

@implementation SPISubmitAuthCodeResult
- (instancetype)initWithValidFormat:(BOOL)isValidFormat
                                msg:(NSString *)message {
    _isValidFormat = isValidFormat;
    _message = message;
    return self;
}
@end

@implementation SPITransactionFlowState

- (instancetype)initWithTid:(NSString *)posRefId
                       type:(SPITransactionType)type
                amountCents:(NSInteger)amountCents
                    message:(SPIMessage *)message
                        msg:(NSString *)msg {
    
    self = [super init];
    
    if (self) {
        self.tid = posRefId.copy;
        self.posRefId = posRefId.copy;
        self.type = type;
        self.amountCents = amountCents;
        self.isRequestSent = NO;
        self.isAwaitingSignatureCheck = NO;
        self.isFinished = NO;
        self.successState = SPIMessageSuccessStateUnknown;
        self.request = message;
        self.displayMessage = msg;
    }
    
    return self;
}

- (NSString *)txTypeString {
    switch (self.type) {
        case SPITransactionTypePurchase:
            return @"PURCHASE";
            
        case SPITransactionTypeRefund:
            return @"REFUND";
            
        case SPITransactionTypeCashoutOnly:
            return @"CASHOUT ONLY";
            break;
        case SPITransactionTypeMOTO:
            return @"MOTO";
            break;
        case SPITransactionTypeSettle:
            return @"SETTLE";
            
        case SPITransactionTypeSettleEnquiry:
            return @"SETTLE ENQUIRY";
            break;
        case SPITransactionTypeGetLastTransaction:
            return @"GET_LAST_TRANSACTION";
        case SPITransactionTypePreAuth:
            return @"PRE AUTH";
            break;
        case SPITransactionTypeAccountVerify:
            return @"ACCOUNT VERIFY";
            break;
    }
}

- (void)sent:(NSString *)msg {
    self.isRequestSent = YES;
    self.requestDate = [NSDate date];
    self.lastStateRequestTime = [NSDate date];
    self.displayMessage = msg;
}

- (void)cancelling:(NSString *)msg {
    self.isAttemptingToCancel = YES;
    self.cancelAttemptTime = [NSDate date];
    self.displayMessage = msg;
}

- (void)callingGlt {
    self.isAwaitingGltResponse = YES;
    self.lastStateRequestTime = [NSDate date];
}

- (void)gotGltResponse {
    self.isAwaitingGltResponse = NO;
}

- (void)failed:(SPIMessage *)response msg:(NSString *)msg {
    self.successState = SPIMessageSuccessStateFailed;
    self.isFinished = YES;
    self.response = response;
    self.displayMessage = msg;
}

- (void)signatureRequired:(SPISignatureRequired *)spiMessage
                      msg:(NSString *)msg {
    self.signatureRequiredMessage = spiMessage;
    self.isAwaitingSignatureCheck = YES;
    self.displayMessage = msg;
}

- (void)signatureResponded:(NSString *)msg {
    self.isAwaitingSignatureCheck = NO;
    self.displayMessage = msg;
}

- (void)completed:(SPIMessageSuccessState)state
         response:(SPIMessage *)response
              msg:(NSString *)msg {
    self.successState = state;
    self.response = response;
    self.isFinished = YES;
    self.isAttemptingToCancel = NO;
    self.isAwaitingGltResponse = NO;
    self.isAwaitingSignatureCheck = NO;
    self.isAwaitingPhoneForAuth = NO;
    self.displayMessage = msg;
}

- (void)unknownCompleted:(NSString *)msg {
    self.successState = SPIMessageSuccessStateUnknown;
    self.response = nil;
    self.isFinished = YES;
    self.isAttemptingToCancel = NO;
    self.isAwaitingGltResponse = NO;
    self.isAwaitingSignatureCheck = NO;
    self.isAwaitingPhoneForAuth = NO;
    self.displayMessage = msg;
}

- (id)copyWithZone:(NSZone *)zone {
    SPITransactionFlowState *state = [SPITransactionFlowState new];
    state.tid = self.tid;
    state.posRefId = self.posRefId;
    state.type = self.type;
    state.displayMessage = self.displayMessage;
    state.amountCents = self.amountCents;
    state.isRequestSent = self.isRequestSent;
    state.requestDate = self.requestDate;
    state.lastStateRequestTime = self.lastStateRequestTime;
    state.isAttemptingToCancel = self.isAttemptingToCancel;
    state.isAwaitingSignatureCheck = self.isAwaitingSignatureCheck;
    state.isFinished = self.isFinished;
    state.successState = self.successState;
    state.response = self.response;
    state.signatureRequiredMessage = self.signatureRequiredMessage;
    state.cancelAttemptTime = self.cancelAttemptTime;
    state.request = self.request;
    state.isAwaitingGltResponse = self.isAwaitingGltResponse;
    
    return state;
}

- (void)phoneForAuthRequired:(SPIPhoneForAuthRequired *)spiMessage
                         msg:(NSString *)msg {
    _phoneForAuthRequiredMessage = spiMessage;
    _isAwaitingGltResponse = true;
    _isAwaitingPhoneForAuth = true;
    _displayMessage = msg;
}

- (void)authCodeSent:(NSString *)msg {
    _isAwaitingPhoneForAuth = false;
    _displayMessage = msg;
}

- (NSString *)description {
    return [self dynamicDescription];
}

@end

@implementation SPIState

+ (NSString *)flowString:(SPIFlow)flow {
    switch (flow) {
        case SPIFlowIdle:
            return @"IDLE";
            
        case SPIFlowPairing:
            return @"PAIRING";
            
        case SPIFlowTransaction:
            return @"TRANSACTION";
    }
}

- (id)copyWithZone:(NSZone *)zone {
    SPIState *state = [SPIState new];
    state.status = self.status;
    state.flow = self.flow;
    state.pairingFlowState = self.pairingFlowState.copy;
    state.txFlowState = self.txFlowState.copy;
    return state;
}

- (NSString *)description {
    return [self dynamicDescription];
}

@end
