//
//  SPILogin.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-27.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPILogin.h"
#import "SPIMessage.h"
#import "SPIRequestIdHelper.h"
#import "NSDate+Util.h"
#import "NSDateFormatter+Util.h"

@implementation SPILoginRequest

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"l"]
                                       eventName:SPILoginRequestKey
                                            data:nil
                                 needsEncryption:YES];
}

@end

@implementation SPILoginResponse

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _isSuccess = ((NSString *)message.data[@"success"]).boolValue;
        _expires   = (NSString *)message.data[@"expires_datetime"];
    }
    
    return self;
}

- (BOOL)expiringSoon:(NSTimeInterval)serverTimeDelta {
    NSDate *currentDate = [NSDate date];
    
    NSDate *nowServerTime = [currentDate dateByAddingTimeInterval:serverTimeDelta];
    nowServerTime = [nowServerTime dateByAddingTimeInterval:10 * 60];
    
    NSDate *expiresAt = [[NSDateFormatter dateFormatter] dateFromString:self.expires];
    
    return [expiresAt compare:nowServerTime] == NSOrderedAscending;
}

@end
