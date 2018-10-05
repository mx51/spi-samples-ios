//
//  SPICashout.m
//  SPIClient-iOS
//
//  Created by Amir Kamali on 30/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPICashout.h"
#import "SPIRequestIdHelper.h"

@implementation SPICashoutOnlyRequest : NSObject

- (instancetype)initWithAmountCents:(NSInteger)amountCents posRefId:(NSString *)posRefId {
    _config = [[SPIConfig alloc] init];
    _cashoutAmount = amountCents;
    _posRefId = posRefId;
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_posRefId forKey:@"pos_ref_id"];
    [data setValue:[NSNumber numberWithInteger:_cashoutAmount] forKey:@"cash_amount"];
    [_config addReceiptConfig:data];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"cshout"]
                                       eventName:SPICashoutOnlyRequestKey
                                            data:data
                                 needsEncryption:true];
}

@end

@implementation SPICashoutOnlyResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _requestid = _message.mid;
        _posRefId = [_message getDataStringValue:@"pos_ref_id"];
        _schemeName = [_message getDataStringValue:@"scheme_name"];
        _isSuccess = _message.successState == SPIMessageSuccessStateSuccess;
    }
    
    return self;
}

- (NSString *)getRRN {
    return [self.message getDataStringValue:@"rrn"];
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

- (NSString *)getCustomerReceipt {
    return [self.message getDataStringValue:@"customer_receipt"];
}

- (NSString *)getMerchantReceipt {
    return [self.message getDataStringValue:@"merchant_receipt"];
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
    return [_message getDataBoolValue:@"merchant_receipt_printed" defaultIfNotFound:false];
}

- (BOOL)wasCustomerReceiptPrinted {
    return [_message getDataBoolValue:@"customer_receipt_printed" defaultIfNotFound:false];
}

- (NSString *)getResponseValue:(NSString *)attribute {
    if (!attribute) return @"";
    
    return (NSString *)self.message.data[attribute] ?: @"";
}

@end
