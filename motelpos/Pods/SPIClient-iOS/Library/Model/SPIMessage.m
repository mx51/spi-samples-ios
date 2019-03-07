//
//  SPIMessage.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-24.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSDate+Util.h"
#import "NSString+Util.h"
#import "SPICrypto.h"
#import "SPILogger.h"
#import "SPIMessage.h"
#import "SPISecrets.h"

NSString *const SPIPairRequestKey = @"pair_request";
NSString *const SPIKeyRequestKey = @"key_request";
NSString *const SPIKeyResponseKey = @"key_response";
NSString *const SPIKeyCheckKey = @"key_check";
NSString *const SPIPairResponseKey = @"pair_response";
NSString *const SPIDropKeysAdviceKey = @"drop_keys";

NSString *const SPILoginRequestKey = @"login_request";
NSString *const SPILoginResponseKey = @"login_response";

NSString *const SPIPingKey = @"ping";
NSString *const SPIPongKey = @"pong";

NSString *const SPIPurchaseRequestKey = @"purchase";
NSString *const SPIPurchaseResponseKey = @"purchase_response";

NSString *const SPICancelTransactionRequestKey = @"cancel_transaction";
NSString *const SPICancelTransactionResponseKey = @"cancel_response";

NSString *const SPIGetLastTransactionRequestKey = @"get_last_transaction";
NSString *const SPIGetLastTransactionResponseKey = @"last_transaction";

NSString *const SPIRefundRequestKey = @"refund";
NSString *const SPIRefundResponseKey = @"refund_response";
NSString *const SPISignatureRequiredKey = @"signature_required";
NSString *const SPISignatureDeclinedKey = @"signature_decline";
NSString *const SPISignatureAcceptedKey = @"signature_accept";

NSString *const SPIAuthCodeRequiredKey = @"authorisation_code_required";
NSString *const SPIAuthCodeAdviceKey = @"authorisation_code_advice";

NSString *const SPICashoutOnlyRequestKey = @"cash";
NSString *const SPICashoutOnlyResponseKey = @"cash_response";

NSString *const SPIMotoPurchaseRequestKey = @"moto_purchase";
NSString *const SPIMotoPurchaseResponseKey = @"moto_purchase_response";

NSString *const SPISettleRequestKey = @"settle";
NSString *const SPISettleResponseKey = @"settle_response";
NSString *const SPISettlementEnquiryRequestKey = @"settlement_enquiry";
NSString *const SPISettlementEnquiryResponseKey = @"settlement_enquiry_response";

NSString *const SPISetPosInfoRequestKey = @"set_pos_info";
NSString *const SPISetPosInfoResponseKey = @"set_pos_info_response";

NSString *const SPIKeyRollRequestKey = @"request_use_next_keys";
NSString *const SPIKeyRollResponseKey = @"response_use_next_keys";

NSString *const SPIInvalidMessageId = @"_";
NSString *const SPIInvalidHmacSignature = @"_INVALID_SIGNATURE_";
NSString *const SPIEventError = @"error";

NSString *const SPIPayAtTableGetTableConfigKey = @"get_table_config"; // incoming. When eftpos wants to ask us for P@T configuration.
NSString *const SPIPayAtTableSetTableConfigKey = @"set_table_config"; // outgoing. When we want to instruct eftpos with the P@T configuration.
NSString *const SPIPayAtTableGetBillDetailsKey = @"get_bill_details"; // incoming. When eftpos wants to aretrieve the bill for a table.
NSString *const SPIPayAtTableBillDetailsKey = @"bill_details";        // outgoing. We reply with this when eftpos requests to us get_bill_details.
NSString *const SPIPayAtTableBillPaymentKey = @"bill_payment";        // incoming. When the eftpos advices
NSString *const SPIPayAtTableBillPaymentFlowEndedKey = @"bill_payment_flow_ended";
NSString *const SPIPayAtTableGetOpenTablesKey = @"get_open_tables";
NSString *const SPIPayAtTableOpenTablesKey = @"open_tables";

NSString *const SPIPrintingRequestKey = @"print";
NSString *const SPIPrintingResponseKey = @"print_response";

NSString *const SPITerminalStatusRequestKey = @"get_terminal_status";
NSString *const SPITerminalStatusResponseKey = @"terminal_status";

NSString *const SPITerminalConfigurationRequestKey = @"get_terminal_configuration";
NSString *const SPITerminalConfigurationResponseKey = @"terminal_configuration";

NSString *const SPIBatteryLevelChangedKey = @"battery_level_changed";

@implementation SPIMessageStamp

- (instancetype)initWithPosId:(NSString *)posId
                      secrets:(SPISecrets *)secrets
              serverTimeDelta:(NSTimeInterval)serverTimeDelta {
    
    self = [super init];
    
    if (self) {
        _posId = posId.copy;
        self.secrets = secrets;
        _serverTimeDelta = serverTimeDelta;
    }
    
    return self;
}

@end

@implementation SPIMessage

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super init];
    
    if (self) {
        _mid = dict[@"id"];
        _eventName = dict[@"event"];
        _data = dict[@"data"];
        _dateTimeStamp = dict[@"datetime"];
        _posId = dict[@"pos_id"];
        _needsEncryption = NO;
    }
    
    return self;
}

- (instancetype)initWithMessageId:(NSString *)mid
                        eventName:(NSString *)eventName
                             data:(NSDictionary<NSString *, NSObject *> *)data
                  needsEncryption:(BOOL)needsEncryption {
    
    self = [super init];
    
    if (self) {
        _mid = mid.copy;
        _eventName = eventName.copy;
        _data = data.copy;
        _needsEncryption = needsEncryption;
    }
    
    return self;
}

- (BOOL)isSuccess {
    return [self getDataBoolValue:@"success" defaultIfNotFound:false];
}

- (NSString *)error {
    return [self getDataStringValue:@"error_reason"];
}

- (NSString *)errorDetail {
    return [self getDataStringValue:@"error_detail"];
}

- (NSTimeInterval)serverTimeDelta {
    NSDate *now = [NSDate date];
    NSDate *serverDate = [self.dateTimeStamp toDate];
    return [serverDate timeIntervalSinceDate:now];
}

- (SPIMessageSuccessState)successState {
    if (!_successState) {
        if (!self.data) {
            _successState = SPIMessageSuccessStateUnknown;
        } else {
            _successState = [self getDataBoolValue:@"success" defaultIfNotFound:false] ? SPIMessageSuccessStateSuccess : SPIMessageSuccessStateFailed;
        }
    }
    
    return _successState;
}

- (NSString *)toJson:(SPIMessageStamp *)stamp {
    NSDate *currentDate = [NSDate date];
    NSDate *adjustedDate = [currentDate dateByAddingTimeInterval:stamp.serverTimeDelta];
    self.dateTimeStamp = [adjustedDate toString];
    
    if (!self.needsEncryption) {
        self.posId = stamp.posId;
    }
    
    SPIMessageEnvelope *messageEnvelope = [[SPIMessageEnvelope alloc] initWithMessage:self];
    NSDictionary *messageEnvelopeJson = [messageEnvelope toJson];
    
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:messageEnvelopeJson
                                                       options:0
                                                         error:&jsonError];
    
    if (jsonError) {
        SPILog(@"ERROR: Message serialization error: %@", jsonError);
        return nil;
    }
    
    NSString *messageEnvelopeString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    self.decryptedJson = messageEnvelopeString;
    
    if (!self.needsEncryption) {
        return messageEnvelopeString;
    }
    
    NSString *encMsg = [SPICrypto aesEncryptMessage:messageEnvelopeString key:stamp.secrets.encKeyData];
    NSString *hmacSig = [SPICrypto hmacSignatureMessage:encMsg key:stamp.secrets.hmacKeyData];
    
    SPIMessageEnvelope *encrMessageEnvelope = [[SPIMessageEnvelope alloc] initWithEnc:encMsg hmac:hmacSig posId:stamp.posId];
    NSDictionary *encrMessageEnvelopeJson = [encrMessageEnvelope toJson];
    
    jsonData = [NSJSONSerialization dataWithJSONObject:encrMessageEnvelopeJson options:0 error:&jsonError];
    
    if (jsonError) {
        SPILog(@"ERROR: Envelope serialization error: %@", jsonError);
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)getDataStringValue:(NSString *)attribute {
    NSObject *v = self.data[attribute];
    if ([v isKindOfClass:[NSString class]]) {
        return (NSString *)v;
    }
    return @"";
}

- (NSInteger)getDataIntegerValue:(NSString *)attribute {
    NSObject *v = self.data[attribute];
    if (v != [NSNull null]) {
        return ((NSString *)v).integerValue;
    }
    return 0;
}

- (BOOL)getDataBoolValue:(NSString *)attribute defaultIfNotFound:(BOOL)defaultIfNotFound {
    NSObject *v = self.data[attribute];
    if (v != [NSNull null]) {
        return ((NSString *)v).boolValue;
    }
    return defaultIfNotFound;
}

- (NSDictionary *)getDataDictionaryValue:(NSString *)attribute {
    NSObject *v = self.data[attribute];
    if ([v isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)v;
    }
    return [NSDictionary new];
}

- (NSArray *)getDataArrayValue:(NSString *)attribute {
    NSObject *v = self.data[attribute];
    if ([v isKindOfClass:[NSArray class]]) {
        return (NSArray *)v;
    }
    return [NSArray new];
}

+ (SPIMessage *)fromJson:(NSString *)msgJson secrets:(SPISecrets *)secrets {
    NSError *error = nil;
    NSData *mJsonData = [msgJson dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:mJsonData options:0 error:&error];
    
    NSDictionary *message = json[@"message"];
    
    if (message) {
        SPIMessage *m = [[SPIMessage alloc] initWithDict:message];
        m.decryptedJson = msgJson;
        return m;
    }
    
    NSString *enc = json[@"enc"];
    NSString *hmac = json[@"hmac"];
    
    NSString *hmacSig = [SPICrypto hmacSignatureMessage:enc key:secrets.hmacKeyData];
    
    if (![hmacSig isEqualToString:hmac]) {
        return [[SPIMessage alloc] initWithMessageId:SPIInvalidMessageId
                                           eventName:SPIInvalidHmacSignature
                                                data:nil
                                     needsEncryption:NO];
    }
    
    NSString *aesDecryptedJson = [SPICrypto aesDecryptEncMessage:enc key:secrets.encKeyData];
    
    SPIMessage *m;
    if (aesDecryptedJson != nil) {
        NSData *decryptedJsonData = [aesDecryptedJson dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *newJson = [NSJSONSerialization JSONObjectWithData:decryptedJsonData
                                                                options:NSJSONReadingMutableLeaves
                                                                  error:&error];
        
        if (error) {
            SPILog(@"ERROR: AES decryption error: %@", [[NSString alloc] initWithData:decryptedJsonData encoding:NSUTF8StringEncoding]);
        }
        
        NSDictionary *msgDecryptedJson = (NSDictionary *)newJson[@"message"];
        m = [[SPIMessage alloc] initWithDict:msgDecryptedJson];
    } else {
        m = [[SPIMessage alloc] init];
    }
    
    m.incomingHmac = hmac;
    m.decryptedJson = aesDecryptedJson;
    return m;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    if (self.mid) {
        [dict setObject:self.mid forKey:@"id"];
    }
    
    if (self.eventName) {
        [dict setObject:self.eventName forKey:@"event"];
    } else {
        NSLog(@"ERROR!!!!");
    }
    
    if (self.data) {
        [dict setObject:self.data forKey:@"data"];
    }
    
    if (self.dateTimeStamp) {
        [dict setObject:self.dateTimeStamp forKey:@"datetime"];
    }
    
    if (self.posId) {
        [dict setObject:self.posId forKey:@"pos_id"];
    }
    
    return dict.copy;
}

@end

@implementation SPIMessageEnvelope

- (instancetype)initWithMessage:(SPIMessage *)message
                            enc:(NSString *)enc
                           hmac:(NSString *)hmac {
    
    self = [super init];
    
    if (self) {
        self.message = message;
        _enc = enc.copy;
        _hmac = hmac.copy;
    }
    
    return self;
}

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        self.message = message;
    }
    
    return self;
}

- (instancetype)initWithEnc:(NSString *)enc
                       hmac:(NSString *)hmac
                      posId:(NSString *)posId {
    
    self = [super init];
    
    if (self) {
        _enc = enc.copy;
        _hmac = hmac.copy;
        _posId = posId.copy;
    }
    
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    if (self.message != nil) {
        [dict setObject:[self.message toJson] forKey:@"message"];
    }
    
    if (self.enc) {
        [dict setObject:self.enc forKey:@"enc"];
    }
    
    if (self.hmac) {
        [dict setObject:self.hmac forKey:@"hmac"];
    }
    
    if (self.posId) {
        [dict setObject:self.posId forKey:@"pos_id"];
    }
    
    return dict.copy;
}

@end
