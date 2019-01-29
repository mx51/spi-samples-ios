//
//  SPIPrinting.h
//  SPIClient-iOS
//
//  Created by Metin Avci on 14/9/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"

@interface SPIPrintingRequest : NSObject

@property (nonatomic, readonly, copy) NSString *infoId;
@property (nonatomic, readonly, copy) NSString *key;
@property (nonatomic, readonly, copy) NSString *payload;

- (instancetype)initWithKey:(NSString *)key
                    payload:(NSString *)payload;

- (SPIMessage *)toMessage;

@end

@interface SPIPrintingResponse : NSObject

@property (nonatomic, readonly, strong) SPIMessage *message;
@property (nonatomic, readonly) BOOL isSuccess;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getErrorReason;

- (NSString *)getErrorDetail;

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute;

@end
