//
//  SPITransaction.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSDateFormatter+Util.h"
#import "SPIClient.h"
#import "SPIMessage.h"
#import "SPITransaction.h"
#import "SPIRequestIdHelper.h"

@implementation SPIPurchaseRequest : NSObject

- (instancetype)initWithAmountCents:(NSInteger)amountCents
                           posRefId:(NSString *)posRefId {
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _posRefId = posRefId;
        _purchaseAmount = amountCents;
        
        // Library Backwards Compatibility
        _purchaseId = posRefId;
        _amountCents = amountCents;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSDictionary *originalData = @{
                                   @"pos_ref_id" : self.posRefId,
                                   @"purchase_amount" : @(self.purchaseAmount),
                                   @"tip_amount" : @(self.tipAmount),
                                   @"cash_amount" : @(self.cashoutAmount),
                                   @"prompt_for_cashout" : @(self.promptForCashout),
                                   @"surcharge_amount" : @(self.surchargeAmount),
                                   };
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithDictionary:originalData];
    [_config addReceiptConfig:data enabledPromptForCustomerCopyOnEftpos:true enabledSignatureFlowOnEftpos:true enabledPrintMerchantCopy:true];
    [_options addOptions:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"prchs"]
                                       eventName:SPIPurchaseRequestKey
                                            data:data
                                 needsEncryption:true];
}

- (NSString *)amountSummary {
    return [NSString stringWithFormat:@"Purchase: %.2f; Tip: %.2f; Cashout: %.2f; Surcharge: %.2f;",
            ((float)_purchaseAmount / 100.0),
            ((float)_tipAmount / 100.0),
            ((float)_cashoutAmount / 100.0),
            ((float)_surchargeAmount / 100.0)];
}

@end

@implementation SPIPurchaseResponse

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _requestid = message.mid;
        _schemeName = [message getDataStringValue:@"scheme_name"];
        _posRefId = [message getDataStringValue:@"pos_ref_id"];
        _isSuccess = message.successState == SPIMessageSuccessStateSuccess;
    }
    
    return self;
}

- (NSString *)getRRN {
    return [self.message getDataStringValue:@"rrn"];
}

- (NSString *)getMerchantReceipt {
    return [self.message getDataStringValue:@"merchant_receipt"];
}

- (NSString *)getCustomerReceipt {
    return [self.message getDataStringValue:@"customer_receipt"];
}

- (NSString *)getResponseText {
    return [self.message getDataStringValue:@"host_response_text"];
}

- (NSString *)getResponseCode {
    return [self.message getDataStringValue:@"host_response_code"];
}

- (NSString *)getTerminalReferenceId {
    return [self.message getDataStringValue:@"terminal_ref_id"];
}

- (NSString *)getCardEntry {
    return [self.message getDataStringValue:@"card_entry"];
}

- (NSString *)getAccountType {
    return [self.message getDataStringValue:@"account_type"];
}

- (NSString *)getAuthCode {
    return [self.message getDataStringValue:@"auth_code"];
}

- (NSString *)getBankDate {
    return [self.message getDataStringValue:@"bank_date"];
}

- (NSString *)getBankTime {
    return [self.message getDataStringValue:@"bank_time"];
}

- (NSString *)getMaskedPan {
    return [self.message getDataStringValue:@"masked_pan"];
}

- (NSString *)getTerminalId {
    return [self.message getDataStringValue:@"terminal_id"];
}

- (BOOL)wasMerchantReceiptPrinted {
    return [self.message getDataBoolValue:@"merchant_receipt_printed" defaultIfNotFound:false];
}

- (BOOL)wasCustomerReceiptPrinted {
    return [self.message getDataBoolValue:@"customer_receipt_printed" defaultIfNotFound:false];
}

- (NSDate *)getSettlementDate {
    NSString *dateStr = [_message getDataStringValue:@"bank_settlement_date"];
    if (dateStr.length == 0) {
        return nil;
    }
    return [[NSDateFormatter bankSettlementFormatter] dateFromString:dateStr];
}

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute {
    return [self.message getDataStringValue:attribute];
}

- (NSInteger)getPurchaseAmount {
    return [self.message getDataIntegerValue:@"purchase_amount"];
}

- (NSInteger)getTipAmount {
    return [self.message getDataIntegerValue:@"tip_amount"];
}

- (NSInteger)getCashoutAmount {
    return [self.message getDataIntegerValue:@"cash_amount"];
}

- (NSInteger)getBankNonCashAmount {
    return [self.message getDataIntegerValue:@"bank_noncash_amount"];
}

- (NSInteger)getBankCashAmount {
    return [self.message getDataIntegerValue:@"bank_cash_amount"];
}

- (NSInteger)getSurchargeAmount {
    return [self.message getDataIntegerValue:@"surcharge_amount"];
}

- (NSDictionary *)toPaymentSummary {
    return @{
             @"account_type": [self getAccountType],
             @"auth_code": [self getAuthCode],
             @"bank_date": [self getBankDate],
             @"bank_time": [self getBankTime],
             @"host_response_code": [self getResponseCode],
             @"host_response_text": [self getResponseText],
             @"masked_pan": [self getMaskedPan],
             @"purchase_amount": [NSNumber numberWithInteger:[self getPurchaseAmount]],
             @"rrn": [self getRRN],
             @"scheme_name": _schemeName,
             @"terminal_id": [self getTerminalId],
             @"terminal_ref_id": [self getTerminalReferenceId],
             @"tip_amount": [NSNumber numberWithInteger:[self getTipAmount]],
             @"surcharge_amount": [NSNumber numberWithInteger:[self getSurchargeAmount]]
             };
}

@end

@implementation SPICancelTransactionRequest : NSObject

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"ctx"]
                                       eventName:SPICancelTransactionRequestKey
                                            data:nil
                                 needsEncryption:true];
}

@end

@implementation SPICancelTransactionResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _posRefId = [message getDataStringValue:@"pos_ref_id"];
        _isSuccess = [message isSuccess];
    }
    
    return self;
}

- (NSString *)getErrorReason {
    return [self.message getDataStringValue:@"error_reason"];
}

- (NSString *)getErrorDetail {
    return [self.message getDataStringValue:@"error_detail"];
}

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute {
    return [self.message getDataStringValue:attribute];
}

@end

@implementation SPIGetLastTransactionRequest : NSObject

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"glt"]
                                       eventName:SPIGetLastTransactionRequestKey
                                            data:nil
                                 needsEncryption:true];
}

@end

@implementation SPIGetLastTransactionResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
    }
    
    return self;
}

- (BOOL)wasRetrievedSuccessfully {
    // We can't rely on checking "success" flag or "error" fields here,
    // as retrieval may be successful, but the retrieved transaction was a fail.
    // So we check if we got back an ResponseCode.
    // (as opposed to say an operation_in_progress_error)
    NSString *code = [self getResponseCode];
    return !(code == nil || code.length == 0);
}

- (BOOL)wasTimeOutOfSyncError {
    return [self.message.error hasPrefix:@"TIME_OUT_OF_SYNC"];
}

- (BOOL)wasOperationInProgressError {
    return [self.message.error hasPrefix:@"OPERATION_IN_PROGRESS"];
}

- (BOOL)isWaitingForSignatureResponse {
    return [self.message.error hasPrefix:@"OPERATION_IN_PROGRESS_AWAITING_SIGNATURE"];
}

- (BOOL)isWaitingForAuthCode {
    return [self.message.error hasPrefix:@"OPERATION_IN_PROGRESS_AWAITING_PHONE_AUTH_CODE"];
}

- (BOOL)isStillInProgress:(NSString *)posRefId {
    return ([self wasOperationInProgressError] && ([posRefId isEqualToString:[self getPosRefId]] || [self getPosRefId] == nil));
}

- (SPIMessageSuccessState)getSuccessState {
    return [_message successState];
}

- (BOOL)wasSuccessfulTx {
    return self.message.successState == SPIMessageSuccessStateSuccess;
}

- (NSString *)getTxType {
    return [self.message getDataStringValue:@"transaction_type"];
}

- (NSString *)getPosRefId {
    return [self.message getDataStringValue:@"pos_ref_id"];
}

- (NSInteger)getBankNonCashAmount {
    return [self.message getDataIntegerValue:@"bank_noncash_amount"];
}

- (NSString *)getSchemeApp {
    return [self.message getDataStringValue:@"scheme_name"];
}

- (NSString *)getSchemeName {
    return [self.message getDataStringValue:@"scheme_name"];
}

- (NSInteger)getAmount {
    return [self.message getDataIntegerValue:@"purchase_amount"];
}

- (NSInteger)getTransactionAmount {
    return [self.message getDataIntegerValue:@"amount_transaction_type"];
}

- (NSString *)getBankDateTimeString {
    // bank_date":"07092017","bank_time":"152137"
    NSString *date = [self.message getDataStringValue:@"bank_date"];
    NSString *time = [self.message getDataStringValue:@"bank_time"];
    
    if (!date || !time) return nil;
    
    // ddMMyyyyHHmmss
    return [NSString stringWithFormat:@"%@%@", date, time];
}

- (NSString *)getRRN {
    return [self.message getDataStringValue:@"rrn"];
}

- (NSString *)getResponseText {
    return [self.message getDataStringValue:@"host_response_text"];
}

- (NSString *)getResponseCode {
    return [self.message getDataStringValue:@"host_response_code"];
}

- (void)copyMerchantReceiptToCustomerReceipt {
    NSString *cr = [self.message getDataStringValue:@"customer_receipt"];
    NSString *mr = [self.message getDataStringValue:@"merchant_receipt"];
    
    if (cr.length != 0 && mr.length != 0) {
        NSMutableDictionary *data = self.message.data.mutableCopy;
        data[@"customer_receipt"] = mr;
        self.message.data = data.copy;
    }
}

@end

@implementation SPIRefundRequest : NSObject

- (instancetype)initWithPosRefId:(NSString *)posRefId
                     amountCents:(NSInteger)amountCents {
    
    self = [super init];
    
    if (self) {
        _refundId = [SPIRequestIdHelper idForString:@"refund"];
        _posRefId = posRefId;
        _amountCents = amountCents;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSDictionary *originalData = @{
                                   @"refund_amount": @(self.amountCents),
                                   @"pos_ref_id": self.posRefId,
                                   @"suppress_merchant_password":@(self.suppressMerchantPassword)
                                   };
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithDictionary:originalData];
    [_config addReceiptConfig:data enabledPromptForCustomerCopyOnEftpos:true enabledSignatureFlowOnEftpos:true enabledPrintMerchantCopy:true];
    [_options addOptions:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"refund"]
                                       eventName:SPIRefundRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIRefundResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _requestId = message.mid;
        _schemeName = [message getDataStringValue:@"scheme_name"];
        _isSuccess = message.isSuccess;
    }
    
    return self;
}

- (NSInteger)getRefundAmount {
    return [self.message getDataIntegerValue:@"refund_amount"];
}

- (NSString *)getRRN {
    return [self.message getDataStringValue:@"rrn"];
}

- (NSString *)getCustomerReceipt {
    return [self.message getDataStringValue:@"customer_receipt"];
}

- (NSString *)getMerchantReceipt {
    return [self.message getDataStringValue:@"merchant_receipt"];
}

- (NSDate *)getSettlementDate {
    NSString *dateStr = [_message getDataStringValue:@"bank_settlement_date"];
    if (dateStr.length == 0) {
        return nil;
    }
    return [[NSDateFormatter bankSettlementFormatter] dateFromString:dateStr];
}

- (NSString *)getResponseText {
    return [self.message getDataStringValue:@"host_response_text"];
}

- (NSString *)getResponseCode {
    return [self.message getDataStringValue:@"host_response_code"];
}

- (NSString *)getTerminalReferenceId {
    return [self.message getDataStringValue:@"terminal_ref_id"];
}

- (NSString *)getCardEntry {
    return [self.message getDataStringValue:@"card_entry"];
}

- (NSString *)getAccountType {
    return [self.message getDataStringValue:@"account_type"];
}

- (NSString *)GetAuthCode {
    return [self.message getDataStringValue:@"auth_code"];
}

- (NSString *)getBankDate {
    return [self.message getDataStringValue:@"bank_date"];
}

- (NSString *)getBankTime {
    return [self.message getDataStringValue:@"bank_time"];
}

- (NSString *)getMaskedPan {
    return [self.message getDataStringValue:@"masked_pan"];
}

- (NSString *)getTerminalId {
    return [self.message getDataStringValue:@"terminal_id"];
}

- (BOOL)wasMerchantReceiptPrinted {
    return [self.message getDataBoolValue:@"merchant_receipt_printed" defaultIfNotFound:false];
}

- (BOOL)wasCustomerReceiptPrinted {
    return [self.message getDataBoolValue:@"customer_receipt_printed" defaultIfNotFound:false];
}

- (NSString *)getResponseValue:(NSString *)attribute {
    if (!attribute) {
        return @"";
    }
    return (NSString *)self.message.data[attribute] ?: @"";
}

@end

@interface SPISignatureRequired () {
    NSString *_receiptToSign;
}

@end

@implementation SPISignatureRequired : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _requestId = message.mid;
        _posRefId = [message getDataStringValue:@"pos_ref_id"];
        _receiptToSign = [message getDataStringValue:@"merchant_receipt"];
    }
    
    return self;
}

- (instancetype)initWithPosRefId:(NSString *)posRefId
                       requestId:(NSString *)requestId
                   receiptToSign:(NSString *)receiptToSign {
    
    self = [super init];
    
    if (self) {
        _posRefId = posRefId;
        _requestId = requestId;
        _receiptToSign = receiptToSign;
    }
    
    return self;
}

- (NSString *)getMerchantReceipt {
    return _receiptToSign;
}

@end

@implementation SPISignatureDecline : NSObject

- (instancetype)initWithSignatureRequiredRequestId:(NSString *)signatureRequiredRequestId {
    self = [super init];
    
    if (self) {
        _signatureRequiredRequestId = [signatureRequiredRequestId copy];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.signatureRequiredRequestId
                                       eventName:SPISignatureDeclinedKey
                                            data:nil
                                 needsEncryption:true];
}

@end

@implementation SPISignatureAccept : NSObject

- (instancetype)initWithSignatureRequiredRequestId:(NSString *)signatureRequiredRequestId {
    self = [super init];
    
    if (self) {
        _signatureRequiredRequestId = [signatureRequiredRequestId copy];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.signatureRequiredRequestId
                                       eventName:SPISignatureAcceptedKey
                                            data:nil
                                 needsEncryption:true];
}

@end

@implementation SPIMotoPurchaseRequest : NSObject

- (instancetype)initWithAmountCents:(NSInteger)amountCents
                           posRefId:(NSString *)posRefId {
    
    self = [super init];
    
    if (self) {
        _config = [[SPIConfig alloc] init];
        _purchaseAmount = amountCents;
        _posRefId = posRefId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:@(_purchaseAmount) forKey:@"purchase_amount"];
    [data setValue:@(_surchargeAmount) forKey:@"surcharge_amount"];
    [data setValue:@(_suppressMerchantPassword) forKey:@"suppress_merchant_password"];
    [_config addReceiptConfig:data enabledPromptForCustomerCopyOnEftpos:true enabledSignatureFlowOnEftpos:true enabledPrintMerchantCopy:true];
    [_options addOptions:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"moto"]
                                       eventName:SPIMotoPurchaseRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPIMotoPurchaseResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _purchaseResponse = [[SPIPurchaseResponse alloc] initWithMessage:message];
        _posRefId = _purchaseResponse.posRefId;
    }
    
    return self;
}

@end

@interface SPIPhoneForAuthRequired () {
    NSString *_phoneNumber;
    NSString *_merchantId;
}

@end

@implementation SPIPhoneForAuthRequired : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _requestId = message.mid;
        _posRefId = [message getDataStringValue:@"pos_ref_id"];
        _phoneNumber = [message getDataStringValue:@"auth_centre_phone_number"];
        _merchantId = [message getDataStringValue:@"merchant_id"];
    }
    
    return self;
}

- (instancetype)initWithPosRefId:(NSString *)posRefId
                       requestId:(NSString *)requestId
                     phoneNumber:(NSString *)phoneNumber
                      merchantId:(NSString *)merchantId {
    
    self = [super init];
    
    if (self) {
        _requestId = requestId;
        _posRefId = posRefId;
        _phoneNumber = phoneNumber;
        _merchantId = merchantId;
    }
    
    return self;
}

- (NSString *)getPhoneNumber {
    return _phoneNumber;
}

- (NSString *)getMerchantId {
    return _merchantId;
}

@end

@implementation SPIAuthCodeAdvice : NSObject

- (instancetype)initWithPosRefId:(NSString *)posRefId
                        authCode:(NSString *)authCode {
    
    self = [super init];
    
    if (self) {
        _posRefId = posRefId;
        _authCode = authCode;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:_authCode forKey:@"auth_code"];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"authad"]
                                       eventName:SPIAuthCodeAdviceKey
                                            data:data
                                 needsEncryption:true];
}

@end
