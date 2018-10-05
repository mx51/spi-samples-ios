//
//  SPISettleRequest.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-29.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSDateFormatter+Util.h"
#import "NSString+Util.h"
#import "SPIMessage.h"
#import "SPIRequestIdHelper.h"
#import "SPISettlement.h"

@implementation SPISettleRequest

- (instancetype)initWithSettleId:(NSString *)settleId {
    self = [super init];
    
    if (self) {
        _settleId = [settleId copy];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"stl"]
                                       eventName:SPISettleRequestKey
                                            data:nil
                                 needsEncryption:YES];
}

@end

@implementation SPISchemeSettlementEntry

- (instancetype)initWithSchemeName:(NSString *)schemeName
                  settleByAcquirer:(BOOL)settleByAcquirer
                        totalCount:(int)totalCount
                        totalValue:(int)totalValue {
    
    self = [super init];
    
    if (self) {
        _schemeName = schemeName;
        _settleByAcquirer = settleByAcquirer;
        _totalCount = totalCount;
        _totalValue = totalValue;
    }
    
    return self;
}

- (instancetype)initWithData:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        _schemeName = [dictionary valueForKey:@"scheme_name"];
        _settleByAcquirer = [[[dictionary valueForKey:@"scheme_name"] lowercaseString] isEqualToString:@"yes"];
        _totalValue = [NSNumber numberWithInteger:(int)[dictionary valueForKey:@"total_value"]].integerValue;
        _totalCount = [NSNumber numberWithInteger:(int)[dictionary valueForKey:@"total_count"]].integerValue;
    }
    
    return self;
}

@end

@implementation SPISettlement

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _requestId = message.mid;
        _message = message;
        _isSuccess = message.isSuccess;
    }
    
    return self;
}

- (NSInteger)getSettleByAcquirerCount {
    return [self.message getDataIntegerValue:@"accumulated_settle_by_acquirer_count"];
}

- (NSInteger)getSettleByAcquirerValue {
    return [self.message getDataIntegerValue:@"accumulated_settle_by_acquirer_value"];
}

- (NSInteger)getTotalCount {
    return [self.message getDataIntegerValue:@"accumulated_total_count"];
}

- (NSInteger)getTotalValue {
    return [self.message getDataIntegerValue:@"accumulated_total_value"];
}

- (NSDate *)getPeriodStartTime {
    NSString *timeStr = [self.message getDataStringValue:@"settlement_period_start_time"]; // "05:00"
    NSString *dateStr = [self.message getDataStringValue:@"settlement_period_start_date"]; // "05Oct17"
    return [[NSDateFormatter dateFormaterWithFormatter:@"HH:mmddMMMyy"] dateFromString:[NSString stringWithFormat:@"%@%@", timeStr, dateStr]];
}

- (NSDate *)getPeriodEndTime {
    NSString *timeStr = [self.message getDataStringValue:@"settlement_period_end_time"]; // "05:00"
    NSString *dateStr = [self.message getDataStringValue:@"settlement_period_end_date"]; // "05Oct17"
    return [[NSDateFormatter dateFormaterWithFormatter:@"HH:mmddMMMyy"] dateFromString:[NSString stringWithFormat:@"%@%@", timeStr, dateStr]];
}

- (NSDate *)getTriggeredTime {
    NSString *timeStr = [self.message getDataStringValue:@"settlement_triggered_time"]; // "05:00"
    NSString *dateStr = [self.message getDataStringValue:@"settlement_triggered_date"]; // "05Oct17"
    NSString *joinedString = [NSString stringWithFormat:@"%@%@", timeStr, dateStr];
    
    return [joinedString toDateWithFormat:@"HH:mm:ssddMMMyy"];
}

- (NSString *)getResponseText {
    return [self.message getDataStringValue:@"host_response_text"];
}

- (NSString *)getReceipt {
    return [self.message getDataStringValue:@"merchant_receipt"];
}

- (NSString *)getTransactionRange {
    return [self.message getDataStringValue:@"transaction_range"];
}

- (NSString *)getTerminalId {
    return [self.message getDataStringValue:@"terminal_id"];
}

- (NSArray<SPISchemeSettlementEntry *> *)getSchemeSettlementEntries {
    NSArray *schemes = [_message getDataArrayValue:@"schemes"];
    NSMutableArray<SPISchemeSettlementEntry *> *entries = [[NSMutableArray alloc] init];
    for (NSDictionary *item in schemes) {
        [entries addObject:[[SPISchemeSettlementEntry alloc] initWithData:item]];
    }
    return entries;
}

@end

@implementation SPISettlementEnquiryRequest

- (instancetype)initWithRequestId:(NSString *)requestId {
    self = [super init];
    
    if (self) {
        _requestId = requestId;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:_requestId
                                       eventName:SPISettlementEnquiryRequestKey
                                            data:nil
                                 needsEncryption:true];
}

@end
