//
//  SPIPurchase.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIPurchase.h"
#import "SPIMessage.h"
#import "SPIRequestIdHelper.h"
#import "NSDateFormatter+Util.h"

@implementation SPIPurchaseRequest : NSObject

- (instancetype)initWithPurchaseId:(NSString *)purchaseId
                       amountCents:(NSInteger)amountCents {
    self = [super init];
    
    if (self) {
        _purchaseId  = [purchaseId copy];
        _amountCents = amountCents;
    }
    
    return self;
    
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.purchaseId
                                       eventName:SPIPurchaseRequestKey
                                            data:@{@"amount_purchase":@(self.amountCents)}
                                 needsEncryption:true];
}

@end

@implementation SPIPurchaseResponse : NSObject
- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message       = message;
        _requestid     = message.mid;
        _schemeName = (NSString *)message.data[@"scheme_name"];
        _isSuccess     = message.successState == SPIMessageSuccessStateSuccess;
    }
    
    return self;
    
}

- (NSString *)getRRN {
    return (NSString *)self.message.data[@"rrn"] ?: @"";
}

- (NSString *)getCustomerReceipt {
    return (NSString *)self.message.data[@"customer_receipt"] ?: @"";
}

- (NSString *)getResponseText {
    return (NSString *)self.message.data[@"host_response_text"] ?: @"";
}

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute {
    if (!attribute) return @"";
    
    return (NSString *)self.message.data[attribute] ?: @"";
}

- (NSString *)hostResponseText {
    return (NSString *)self.message.data[@"host_response_text"];
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
    NSString *rrn = [self getRRN];
    return rrn != nil && ![rrn isEqualToString:@""];
}

- (BOOL)wasOperationInProgressError {
    return [self.message.error isEqualToString:@"OPERATION_IN_PROGRESS"];
}

- (BOOL)wasSuccessfulTx {
    return self.message.successState == SPIMessageSuccessStateSuccess;
}

- (NSString *)getTxType {
    return (NSString *)self.message.data[@"transaction_type"] ?: @"";
}

- (NSString *)getSchemeName {
    return (NSString *)self.message.data[@"scheme_name"] ?: @"";
}

- (NSInteger)getAmount {
    return ((NSString *)self.message.data[@"amount_purchase"]).integerValue;
}

- (NSInteger)getTransactionAmount {
    return ((NSString *)self.message.data[@"amount_transaction_type"]).integerValue;
}

- (NSString *)getRRN {
    return (NSString *)self.message.data[@"rrn"] ?: @"";
}

- (NSString *)getBankDateTimeString {
    // bank_date":"07092017","bank_time":"152137"
    NSString *date = (NSString *)self.message.data[@"bank_date"];
    NSString *time = (NSString *)self.message.data[@"bank_time"];
    
    if (!date || !time) return nil;
    
    // ddMMyyyyHHmmss
    return [NSString stringWithFormat:@"%@%@", date, time];
}

- (NSDate *)bankDate {
    NSString *bankDateTimeString = self.getBankDateTimeString;
    
    if (!bankDateTimeString) return nil;
    
    return [[NSDateFormatter dateNoTimeZoneFormatter] dateFromString:bankDateTimeString];
}

- (SPIMessageSuccessState)successState {
    return self.message.successState;
}

- (NSString *)getResponseValue:(NSString *)attribute {
    if (!attribute) return @"";
    
    return (NSString *)self.message.data[attribute] ?: @"";
}

- (void)copyMerchantReceiptToCustomerReceipt {
    NSString *cr = (NSString *)self.message.data[@"customer_receipt"];
    NSString *mr = (NSString *)self.message.data[@"merchant_receipt"];
    
    if (cr.length != 0 && mr.length != 0) {
        NSMutableDictionary *data = self.message.data.mutableCopy;
        data[@"customer_receipt"] = mr;
        self.message.data         = data.copy;
    }
}

@end

@implementation SPIRefundRequest : NSObject

- (instancetype)initWithRefundId:(NSString *)refundId amountCents:(NSInteger)amountCents {
    
    self = [super init];
    
    if (self) {
        _refundId    = [refundId copy];
        _amountCents = amountCents;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.refundId
                                       eventName:SPIRefundRequestKey
                                            data:@{@"amount_purchase":@(self.amountCents)}
                                 needsEncryption:true];
}

@end

@implementation SPIRefundResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    
    self = [super init];
    
    if (self) {
        _message       = message;
        _requestId     = message.mid;
        _schemeName = (NSString *)message.data[@"scheme_name"];
        _isSuccess     = message.isSuccess;
    }
    
    return self;
    
}

- (NSString *)getRRN {
    return (NSString *)self.message.data[@"rrn"] ?: @"";
}

- (NSString *)getCustomerReceipt {
    return (NSString *)self.message.data[@"customer_receipt"] ?: @"";
}

- (NSString *)getMerchantReceipt {
    return (NSString *)self.message.data[@"merchant_receipt"] ?: @"";
}

- (NSString *)getResponseText {
    return (NSString *)self.message.data[@"host_response_text"] ?: @"";
}

- (NSString *)getResponseValue:(NSString *)attribute {
    if (!attribute) return @"";
    
    return (NSString *)self.message.data[attribute] ?: @"";
}

@end

@implementation SPISignatureRequired : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    
    self = [super init];
    
    if (self) {
        _requestId = message.mid;
        _message   = message;
    }
    
    return self;
    
}

- (NSString *)getMerchantReceipt {
    return (NSString *)self.message.data[@"merchant_receipt"] ?: @"";
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
