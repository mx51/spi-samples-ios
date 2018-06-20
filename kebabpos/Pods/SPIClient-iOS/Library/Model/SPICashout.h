//
//  SPICashout.h
//  SPIClient-iOS
//
//  Created by Amir Kamali on 30/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SPIClient.h"

@interface CashoutOnlyRequest : NSObject
@property (nonatomic, readonly) NSInteger cashoutAmount;
@property (nonatomic, readonly, copy) NSString *posRefId;
@property (nonatomic, retain) SPIConfig *config;

- (SPIMessage *)toMessage;

- (instancetype)initWithAmountCents:(NSInteger)amountCents
                           posRefId:(NSString *)posRefId;

@end

@interface SPICashoutOnlyResponse : NSObject
@property (nonatomic, readonly) BOOL isSuccess;
@property (nonatomic, readonly, copy) NSString *requestid;
@property (nonatomic, readonly, copy) NSString *schemeName;
@property (nonatomic, retain) NSString *posRefId;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getRRN;

- (NSInteger)getCashoutAmount;

- (NSInteger)getBankNonCashAmount;

- (NSInteger)getBankCashAmount;

- (NSString *)getCustomerReceipt;

- (NSString *)getMerchantReceipt;

- (NSString *)getResponseText;

- (NSString *)getResponseCode;

- (NSString *)getTerminalReferenceId;

- (NSString *)getAccountType;

- (NSString *)getAuthCode;

- (NSString *)getBankDate;

- (NSString *)getBankTime;

- (NSString *)getMaskedPan;

- (NSString *)getTerminalId;

- (BOOL)wasMerchantReceiptPrinted;

- (BOOL)wasCustomerReceiptPrinted;

- (NSString *)getResponseValue:(NSString *)attribute;

@end
