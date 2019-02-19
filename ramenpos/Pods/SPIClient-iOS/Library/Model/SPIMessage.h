//
//  SPIMessage.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-24.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPISecrets.h"

// Events statically declares the various event names in messages.
extern NSString *const SPIPairRequestKey;
extern NSString *const SPIKeyRequestKey;
extern NSString *const SPIKeyResponseKey;
extern NSString *const SPIKeyCheckKey;
extern NSString *const SPIPairResponseKey;
extern NSString *const SPIDropKeysAdviceKey;

extern NSString *const SPILoginRequestKey;
extern NSString *const SPILoginResponseKey;

extern NSString *const SPIPingKey;
extern NSString *const SPIPongKey;

extern NSString *const SPIPurchaseRequestKey;
extern NSString *const SPIPurchaseResponseKey;

extern NSString *const SPICancelTransactionRequestKey;
extern NSString *const SPICancelTransactionResponseKey;

extern NSString *const SPIGetLastTransactionRequestKey;
extern NSString *const SPIGetLastTransactionResponseKey;

extern NSString *const SPIRefundRequestKey;
extern NSString *const SPIRefundResponseKey;
extern NSString *const SPISignatureRequiredKey;
extern NSString *const SPISignatureDeclinedKey;
extern NSString *const SPISignatureAcceptedKey;

extern NSString *const SPIAuthCodeRequiredKey;
extern NSString *const SPIAuthCodeAdviceKey;

extern NSString *const SPICashoutOnlyRequestKey;
extern NSString *const SPICashoutOnlyResponseKey;

extern NSString *const SPIMotoPurchaseRequestKey;
extern NSString *const SPIMotoPurchaseResponseKey;

extern NSString *const SPISettleRequestKey;
extern NSString *const SPISettleResponseKey;
extern NSString *const SPISettlementEnquiryRequestKey;
extern NSString *const SPISettlementEnquiryResponseKey;

extern NSString *const SPISetPosInfoRequestKey;
extern NSString *const SPISetPosInfoResponseKey;

extern NSString *const SPIKeyRollRequestKey;
extern NSString *const SPIKeyRollResponseKey;

extern NSString *const SPIInvalidMessageId;
extern NSString *const SPIInvalidHmacSignature;

extern NSString *const SPIEventError;

extern NSString *const SPIPayAtTableGetTableConfigKey; // incoming. When eftpos wants to ask us for P@T configuration.
extern NSString *const SPIPayAtTableSetTableConfigKey; // outgoing. When we want to instruct eftpos with the P@T configuration.
extern NSString *const SPIPayAtTableGetBillDetailsKey; // incoming. When eftpos wants to aretrieve the bill for a table.
extern NSString *const SPIPayAtTableBillDetailsKey;    // outgoing. We reply with this when eftpos requests to us get_bill_details.
extern NSString *const SPIPayAtTableBillPaymentKey;    // incoming. When the eftpos advices
extern NSString *const SPIPayAtTableBillPaymentFlowEndedKey;
extern NSString *const SPIPayAtTableGetOpenTablesKey;
extern NSString *const SPIPayAtTableOpenTablesKey;

extern NSString *const SPIPrintingRequestKey;
extern NSString *const SPIPrintingResponseKey;

extern NSString *const SPITerminalStatusRequestKey;
extern NSString *const SPITerminalStatusResponseKey;

extern NSString *const SPITerminalConfigurationRequestKey;
extern NSString *const SPITerminalConfigurationResponseKey;

extern NSString *const SPIBatteryLevelChangedKey;

typedef NS_ENUM(NSInteger, SPIMessageSuccessState) {
    SPIMessageSuccessStateUnknown,
    SPIMessageSuccessStateSuccess,
    SPIMessageSuccessStateFailed
};

/**
 * MessageStamp represents what is required to turn an outgoing Message into
 * Json including encryption and date setting.
 */
@interface SPIMessageStamp : NSObject

@property (nonatomic, copy) NSString *posId;
@property (nonatomic, strong) SPISecrets *secrets;
@property (nonatomic, assign) NSTimeInterval serverTimeDelta;

- (instancetype)initWithPosId:(NSString *)posId
                      secrets:(SPISecrets *)secrets
              serverTimeDelta:(NSTimeInterval)serverTimeDelta;

@end

/**
 * Message represents the contents of a Message.
 * See http://www.simplepaymentapi.com/#/api/message-encryption
 */
@interface SPIMessage : NSObject

@property (nonatomic, readonly, copy) NSString *mid;
@property (nonatomic, readonly, copy) NSString *eventName;
@property (nonatomic, readonly, copy) NSString *error;
@property (nonatomic, readonly, copy) NSString *errorDetail;

@property (nonatomic, copy) NSDictionary<NSString *, NSObject *> *data;

// Changed when toJson called
@property (nonatomic, copy) NSString *dateTimeStamp;
@property (nonatomic, readonly) NSTimeInterval serverTimeDelta;

// Pos_id is set here only for outgoing Un - encrypted messages.
// (not in the envelope 's top level which would just have the "message" field.)
@property (nonatomic, copy) NSString *posId;

// Sometimes the logic around the incoming message
// might need access to the sugnature, for example in the key_check.
@property (nonatomic, copy) NSString *incomingHmac;

@property (nonatomic) BOOL isSuccess;

@property (nonatomic) SPIMessageSuccessState successState;

// Denotes whether an outgoing message needs to be encrypted in ToJson()
@property (nonatomic) BOOL needsEncryption;

// Set on an incoming message just so you can have a look at what it looked like
// in its json form.
@property (nonatomic, copy) NSString *decryptedJson;

- (instancetype)initWithMessageId:(NSString *)mid
                        eventName:(NSString *)eventName
                             data:(NSDictionary<NSString *, NSObject *> *)data
                  needsEncryption:(BOOL)needsEncryption;

- (instancetype)initWithDict:(NSDictionary *)dict;

- (NSString *)getDataStringValue:(NSString *)attribute;

- (NSInteger)getDataIntegerValue:(NSString *)attribute;

- (BOOL)getDataBoolValue:(NSString *)attribute
       defaultIfNotFound:(BOOL)defaultIfNotFound;

- (NSDictionary *)getDataDictionaryValue:(NSString *)attribute;

- (NSArray *)getDataArrayValue:(NSString *)attribute;

- (NSString *)toJson:(SPIMessageStamp *)stamp;

+ (SPIMessage *)fromJson:(NSString *)msgJson secrets:(SPISecrets *)secrets;

- (NSDictionary *)toJson;

@end

/**
 * MessageEnvelope represents the outer structure of any message that is
 * exchanged between the Pos and the PIN pad and vice-versa. See
 * http://www.simplepaymentapi.com/#/api/message-encryption
 */
@interface SPIMessageEnvelope : NSObject

/** The Message field is set only when in Un-encrypted form.
 * In fact it is the only field in an envelope in the Un-Encrypted form.
 */
@property (nonatomic, strong) SPIMessage *message;

/** The enc field is set only when in Encrypted form.
 * It contains the encrypted Json of another MessageEnvelope
 */
@property (nonatomic, copy) NSString *enc;

/** The hmac field is set only when in Encrypted form.
 *  It is the signature of the "enc" field.
 */
@property (nonatomic, copy) NSString *hmac;

/// The pos_id field is only filled for outgoing Encrypted messages.
@property (nonatomic, copy) NSString *posId;

- (instancetype)initWithMessage:(SPIMessage *)message
                            enc:(NSString *)enc
                           hmac:(NSString *)hmac;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (instancetype)initWithEnc:(NSString *)enc
                       hmac:(NSString *)hmac
                      posId:(NSString *)posId;

- (NSDictionary *)toJson;

@end
