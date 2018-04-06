//
//  SPIMessage.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-24.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIMessage.h"
#import "SPISecrets.h"
#import "SPICrypto.h"
#import "NSDate+Util.h"
#import "NSString+Util.h"
#import "SPILogger.h"

NSString * const SPIPairRequestKey  = @"pair_request";
NSString * const SPIKeyRequestKey   = @"key_request";
NSString * const SPIKeyResponseKey  = @"key_response";
NSString * const SPIKeyCheckKey     = @"key_check";
NSString * const SPIPairResponseKey = @"pair_response";

NSString * const SPILoginRequestKey  = @"login_request";
NSString * const SPILoginResponseKey = @"login_response";

NSString * const SPIPingKey = @"ping";
NSString * const SPIPongKey = @"pong";

NSString * const SPIPurchaseRequestKey            = @"purchase";
NSString * const SPIPurchaseResponseKey           = @"purchase_response";
NSString * const SPICancelTransactionRequestKey   = @"cancel_transaction";
NSString * const SPIGetLastTransactionRequestKey  = @"get_last_transaction";
NSString * const SPIGetLastTransactionResponseKey = @"last_transaction";

NSString * const SPIRefundRequestKey     = @"refund";
NSString * const SPIRefundResponseKey    = @"refund_response";
NSString * const SPISignatureRequiredKey = @"signature_required";
NSString * const SPISignatureDeclinedKey = @"signature_decline";
NSString * const SPISignatureAcceptedKey = @"signature_accept";

NSString * const SPISettleRequestKey  = @"settle";
NSString * const SPISettleResponseKey = @"settle_response";

NSString * const SPIKeyRollRequestKey  = @"request_use_next_keys";
NSString * const SPIKeyRollResponseKey = @"response_use_next_keys";

NSString * const SPIInvalidMessageId     = @"_";
NSString * const SPIInvalidHmacSignature = @"_INVALID_SIGNATURE_";
NSString * const SPIEventError           = @"error";

@implementation SPIMessageStamp

- (instancetype)initWithPosId:(NSString *)posId
                      secrets:(SPISecrets *)secrets
              serverTimeDelta:(NSTimeInterval)serverTimeDelta {
    self = [super init];
    
    if (self) {
        _posId           = posId.copy;
        self.secrets     = secrets;
        _serverTimeDelta = serverTimeDelta;
    }
    
    return self;
}

@end

@implementation SPIMessage

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super init];
    
    if (self) {
        _mid             = dict[@"id"];
        _eventName       = dict[@"event"];
        _data            = dict[@"data"];
        _dateTimeStamp   = dict[@"datetime"];
        _posId           = dict[@"pos_id"];
        _needsEncryption = NO;
    }
    
    return self;
}

- (instancetype)initWithMessageId:(NSString *)mid
                        eventName:(NSString *)eventName
                             data:(NSDictionary <NSString *, NSObject *> *)data
                  needsEncryption:(BOOL)needsEncryption {
    self = [super init];
    
    if (self) {
        _mid             = mid.copy;
        _eventName       = eventName.copy;
        _data            = data.copy;
        _needsEncryption = needsEncryption;
    }
    
    return self;
}

- (BOOL)isSuccess {
    return ((NSString *)_data[@"success"]).boolValue;
}

- (NSString *)error {
    return (NSString *)_data[@"error_reason"];
}

- (NSTimeInterval)serverTimeDelta {
    NSDate *now        = [NSDate date];
    NSDate *serverDate = [self.dateTimeStamp toDate];
    return [serverDate timeIntervalSinceDate:now];
}

- (SPIMessageSuccessState)successState {
    if (!_successState) {
        if (!self.data) {
            _successState = SPIMessageSuccessStateUnknown;
        } else {
            _successState = ((NSString *)self.data[@"success"]).boolValue ? SPIMessageSuccessStateSuccess : SPIMessageSuccessStateFailed;
        }
    }
    
    return _successState;
}

- (NSString *)toJson:(SPIMessageStamp *)stamp {
    NSDate *currentDate  = [NSDate date];
    NSDate *adjustedDate = [currentDate dateByAddingTimeInterval:stamp.serverTimeDelta];
    self.dateTimeStamp = [adjustedDate toString];
    
    if (!self.needsEncryption) {
        self.posId = stamp.posId;
    }
    
    SPIMessageEnvelope *messageEnvelope     = [[SPIMessageEnvelope alloc] initWithMessage:self];
    NSDictionary      *messageEnvelopeJson = [messageEnvelope toJson];
    
    NSError *jsonError = nil;
    NSData  *jsonData  = [NSJSONSerialization dataWithJSONObject:messageEnvelopeJson options:0 error:&jsonError];
    
    if (jsonError) {
        //ERROR
        NSLog(@"toJson jsonError: %@", jsonError);
        return nil;
    }
    
    NSString *messageEnvelopeString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    self.decryptedJson = messageEnvelopeString;
    
    if (!self.needsEncryption) {
        return messageEnvelopeString;
    }
    
    NSString          *encMsg                  = [SPICrypto aesEncryptMessage:messageEnvelopeString key:stamp.secrets.encKeyData];
    NSString          *hmacSig                 = [SPICrypto hmacSignatureMessage:encMsg key:stamp.secrets.hmacKeyData];
    SPIMessageEnvelope *encrMessageEnvelope     = [[SPIMessageEnvelope alloc] initWithEnc:encMsg hmac:hmacSig posId:stamp.posId];
    NSDictionary      *encrMessageEnvelopeJson = [encrMessageEnvelope toJson];
    
    //NSLog(@"toJson messageEnvelopeString: %@",   messageEnvelopeString);
    //NSLog(@"toJson stamp.secrets.encKey: %@",    stamp.secrets.encKey);
    //NSLog(@"toJson encMsg: %@",                  messageEnvelopeString);
    //
    //NSLog(@"toJson encMsg: %@",                  encMsg);
    //NSLog(@"toJson hmacSig: %@",                 hmacSig);
    //NSLog(@"toJson stamp.posId: %@",             stamp.posId);
    //
    //NSLog(@"toJson encrMessageEnvelopeJson: %@", encrMessageEnvelopeJson);
    
    jsonData = [NSJSONSerialization dataWithJSONObject:encrMessageEnvelopeJson options:0 error:&jsonError];
    
    if (jsonError) {
        //ERROR
        NSLog(@"jsonError: %@", jsonError);
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (SPIMessage *)fromJson:(NSString *)msgJson secrets:(SPISecrets *)secrets {
    
    NSLog(@"\nSPIMessage fromJson: %@", msgJson);
    
    NSError      *error     = nil;
    NSData       *mJsonData = [msgJson dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json      = [NSJSONSerialization JSONObjectWithData:mJsonData
                                                              options:0
                                                                error:&error];
    
    NSDictionary *message = json[@"message"];
    
    if (message) {
        SPIMessage *m = [[SPIMessage alloc] initWithDict:message];
        m.decryptedJson = msgJson;
        return m;
    }
    
    NSString *enc  = json[@"enc"];
    NSString *hmac = json[@"hmac"];
    
    NSString *hmacSig = [SPICrypto hmacSignatureMessage:enc key:secrets.hmacKeyData];
    
    if (![hmacSig isEqualToString:hmac]) {
        return [[SPIMessage alloc] initWithMessageId:SPIInvalidMessageId eventName:SPIInvalidHmacSignature data:nil needsEncryption:NO];
    }
    
    NSString *aesDecryptedJson = [SPICrypto aesDecryptEncMessage:enc key:secrets.encKeyData];
    
    NSData       *decryptedJsonData = [aesDecryptedJson dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *newJson           = [NSJSONSerialization JSONObjectWithData:decryptedJsonData
                                                                      options:NSJSONReadingMutableLeaves
                                                                        error:&error];
    
    if (error) {
        NSLog(@"ERROR!!~ =%@", error);
        NSLog(@"%@",           [[NSString alloc] initWithData:decryptedJsonData encoding:NSUTF8StringEncoding]);
    }
    
    NSDictionary *msgDecryptedJson = (NSDictionary *)newJson[@"message"];
    
    SPIMessage *m = [[SPIMessage alloc] initWithDict:msgDecryptedJson];
    m.incomingHmac  = hmac;
    m.decryptedJson = aesDecryptedJson;
    return m;
}

- (NSString *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    if (self.mid) {[dict setObject:self.mid forKey:@"id"]; }
    
    if (self.eventName) {[dict setObject:self.eventName forKey:@"event"]; } else {
        NSLog(@"ERROR!!!!");
    }
    
    if (self.data) {[dict setObject:self.data forKey:@"data"]; }
    
    if (self.dateTimeStamp) {[dict setObject:self.dateTimeStamp forKey:@"datetime"]; }
    
    if (self.posId) {[dict setObject:self.posId forKey:@"pos_id"]; }
    
    return dict.copy;
    
}

+ (NSString *)successStateToString:(SPIMessageSuccessState)success {
    switch (success) {
        case SPIMessageSuccessStateUnknown:
            return @"UNKNOWN";
            
        case SPIMessageSuccessStateSuccess:
            return @"SUCCESS";
            
        case SPIMessageSuccessStateFailed:
            return @"FAILED";
    }
}

@end

@implementation SPIMessageEnvelope

- (instancetype)initWithMessage:(SPIMessage *)message
                            enc:(NSString *)enc
                           hmac:(NSString *)hmac {
    self = [super init];
    
    if (self) {
        self.message = message;
        _enc         = enc.copy;
        _hmac        = hmac.copy;
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
        _enc   = enc.copy;
        _hmac  = hmac.copy;
        _posId = posId.copy;
    }
    
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    if (self.message != nil) {[dict setObject:[self.message toJson] forKey:@"message"]; }
    
    if (self.enc) {[dict setObject:self.enc forKey:@"enc"]; }
    
    if (self.hmac) {[dict setObject:self.hmac forKey:@"hmac"]; }
    
    if (self.posId) {[dict setObject:self.posId forKey:@"pos_id"]; }
    
    return dict.copy;
}

@end
