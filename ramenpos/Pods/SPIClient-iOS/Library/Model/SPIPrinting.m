//
//  SPIPrinting.m
//  SPIClient-iOS
//
//  Created by Metin Avci on 14/9/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIPrinting.h"
#import "SPIRequestIdHelper.h"

@implementation SPIPrintingRequest

- (instancetype)initWithKey:(NSString *)key
                    payload:(NSString *)payload{
    
    self = [super init];
    
    if (self) {
        _infoId = [SPIRequestIdHelper idForString:@"print"];
        _key = key;
        _payload = payload;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.infoId
                                       eventName:SPIPrintingRequestKey
                                            data:@{
                                                   @"key": self.key,
                                                   @"payload": self.payload
                                                   }
                                 needsEncryption:true];
}

@end

@implementation SPIPrintingResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _isSuccess = [message isSuccess];
    }
    
    return self;
}

- (NSString *)getErrorReason {
    return [self.message getDataStringValue:@"error_reason"];
}

- (NSString *)getErrorDetail {
    return [self.message getDataStringValue:@"error_detail"];
}

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute {
    return [self.message getDataStringValue:attribute];
}

@end
