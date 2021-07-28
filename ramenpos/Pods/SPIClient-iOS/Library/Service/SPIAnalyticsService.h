//
//  SPIAnalyticsService.h
//  SPIClient-iOS
//
//  Created by Doniyorjon Zuparov on 09/07/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SPITransactionReport : NSObject

@property (nonatomic, copy) NSString *posVendorId;
@property (nonatomic, copy) NSString *posVersion;
@property (nonatomic, copy) NSString *libraryLanguage;
@property (nonatomic, copy) NSString *libraryVersion;
@property (nonatomic, copy) NSString *posRefId;
@property (nonatomic, copy) NSString *serialNumber;
@property (nonatomic, copy) NSString *event;
@property (nonatomic, copy) NSString *txType;
@property (nonatomic, copy) NSString *txResult;
@property (nonatomic, copy) NSNumber *txStartTime;
@property (nonatomic, copy) NSNumber *txEndTime;
@property (nonatomic, copy) NSNumber *durationMs;
@property (nonatomic, copy) NSString *currentFlow;
@property (nonatomic, copy) NSString *currentTxFlowState;
@property (nonatomic, copy) NSString *currentStatus;

- (NSString *)toJson;

@end

@interface SPIAnalyticsService : NSObject

+ (void)reportTransaction:(SPITransactionReport *)transactionReport
                  apiKey:(NSString *)apiKey
            acquirerCode:(NSString *)acquirerCode
              isTestMode:(BOOL)isTestMode;


@end
