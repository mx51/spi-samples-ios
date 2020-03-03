//
//  SPIModels.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2018-01-13.
//  Copyright © 2018 mx51. All rights reserved.
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

- (instancetype)initWithValidFormat:(BOOL)isValidFormat msg:(NSString *)message {
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self.tid = posRefId.copy;
#pragma clang diagnostic pop
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

+ (NSString *)txTypeString:(SPITransactionType)type {
    switch (type) {
        case SPITransactionTypePurchase:
            return @"Purchase";
            
        case SPITransactionTypeRefund:
            return @"Refund";
            
        case SPITransactionTypeCashoutOnly:
            return @"Cashout Only";
            
        case SPITransactionTypeMOTO:
            return @"MOTO";
            
        case SPITransactionTypeSettle:
            return @"Settle";
            
        case SPITransactionTypeSettleEnquiry:
            return @"Settlement Enquiry";
            
        case SPITransactionTypeGetLastTransaction:
            return @"Get Last Transaction";
            
        case SPITransactionTypePreAuth:
            return @"Preauth";
            
        case SPITransactionTypeAccountVerify:
            return @"Account Verify";
    }
}

- (NSString *)txTypeString {
    return [SPITransactionFlowState txTypeString:self.type];
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

- (void)cancelFailed:(NSString *)msg {
    self.isAttemptingToCancel = NO;
    self.displayMessage = msg;
}

- (void)callingGlt:(NSString *)gltRequestId {
    self.isAwaitingGltResponse = YES;
    self.lastStateRequestTime = [NSDate date];
    self.lastGltRequestId = gltRequestId;
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

- (void)signatureRequired:(SPISignatureRequired *)spiMessage msg:(NSString *)msg {
    self.signatureRequiredMessage = spiMessage;
    self.isAwaitingSignatureCheck = YES;
    self.displayMessage = msg;
}

- (void)signatureResponded:(NSString *)msg {
    self.isAwaitingSignatureCheck = NO;
    self.displayMessage = msg;
}

- (void)completed:(SPIMessageSuccessState)state response:(SPIMessage *)response msg:(NSString *)msg {
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    state.tid = self.tid;
#pragma clang diagnostic pop
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
    state.gltResponsePosRefId = self.gltResponsePosRefId;
    state.lastGltRequestId = self.lastGltRequestId;
    
    return state;
}

- (void)phoneForAuthRequired:(SPIPhoneForAuthRequired *)spiMessage msg:(NSString *)msg {
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
    state.deviceAddressStatus = self.deviceAddressStatus.copy;
    return state;
}

- (NSString *)description {
    return [self dynamicDescription];
}

@end

@implementation SPIConfig

- (void)addReceiptConfig:(NSMutableDictionary *)data
enabledPromptForCustomerCopyOnEftpos:(BOOL)enabledPromptForCustomerCopyOnEftpos
 enabledSignatureFlowOnEftpos:(BOOL)enabledSignatureFlowOnEftpos
     enabledPrintMerchantCopy:(BOOL)enabledPrintMerchantCopy{
    if (_promptForCustomerCopyOnEftpos && enabledPromptForCustomerCopyOnEftpos) {
        [data setObject:[NSNumber numberWithBool:_promptForCustomerCopyOnEftpos] forKey:@"prompt_for_customer_copy"];
    }
    if (_signatureFlowOnEftpos && enabledSignatureFlowOnEftpos) {
        [data setObject:[NSNumber numberWithBool:_signatureFlowOnEftpos] forKey:@"print_for_signature_required_transactions"];
    }
    if (_printMerchantCopy && enabledPrintMerchantCopy) {
        [data setObject:[NSNumber numberWithBool:_printMerchantCopy] forKey:@"print_merchant_copy"];
    }
}

@end

@implementation SPITransactionOptions : NSObject

- (void)addOptions:(NSMutableDictionary *)data {
    [self addOptionObject:_customerReceiptHeader forKey:@"customer_receipt_header" to:data];
    [self addOptionObject:_customerReceiptFooter forKey:@"customer_receipt_footer" to:data];
    [self addOptionObject:_merchantReceiptHeader forKey:@"merchant_receipt_header" to:data];
    [self addOptionObject:_merchantReceiptFooter forKey:@"merchant_receipt_footer" to:data];
}

- (void)addOptionObject:(id)object forKey:(id)key to:(NSMutableDictionary *)data {
    if (object != nil) {
        [data setObject:object forKey:key];
    } else {
        [data removeObjectForKey:key];
    }
}

@end
