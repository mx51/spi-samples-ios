//
//  SPISettleRequest.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SPIMessage;

@interface SPISettleRequest : NSObject

@property (nonatomic, readonly, copy) NSString *settleId;

- (instancetype)initWithSettleId:(NSString *)settleId;

- (SPIMessage *)toMessage;

@end

@interface SPISchemeSettlementEntry : NSObject

@property (nonatomic, readonly, copy) NSString *schemeName;
@property (nonatomic) BOOL settleByAcquirer;
@property (nonatomic) NSInteger totalCount;
@property (nonatomic) NSInteger totalValue;

- (instancetype)initWithSchemeName:(NSString *)schemeName
                  settleByAcquirer:(BOOL)settleByAcquirer
                        totalCount:(int)totalCount
                        totalValue:(int)totalValue;

- (instancetype)initWithData:(NSDictionary *)dictionary;

@end

@interface SPISettlement : NSObject

@property (nonatomic, readonly, copy) NSString *requestId;
@property (nonatomic, readonly, assign) BOOL isSuccess;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSInteger)getSettleByAcquirerCount;

- (NSInteger)getSettleByAcquirerValue;

- (NSInteger)getTotalCount;

- (NSInteger)getTotalValue;

- (NSDate *)getPeriodStartTime;

- (NSDate *)getPeriodEndTime;

- (NSDate *)getTriggeredTime;

- (NSString *)getResponseText;

- (NSString *)getReceipt;

- (NSString *)getTransactionRange;

- (NSString *)getTerminalId;

- (NSArray<SPISchemeSettlementEntry *> *)getSchemeSettlementEntries;

@end

@interface SPISettlementEnquiryRequest : NSObject

@property (nonatomic, readonly, copy) NSString *requestId;

- (instancetype)initWithRequestId:(NSString *)requestId;

- (SPIMessage *)toMessage;

@end
