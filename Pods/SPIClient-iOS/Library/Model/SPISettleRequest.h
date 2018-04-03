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

@interface SPISettlement : NSObject
@property (nonatomic, readonly, copy) NSString     *requestId;
@property (nonatomic, readonly, assign) BOOL       isSuccess;
@property (nonatomic, readonly, strong) SPIMessage *message;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getResponseText;

- (NSString *)getReceipt;

@end
