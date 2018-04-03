//
//  SPILogin.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-27.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPIMessage.h"

@interface SPILoginRequest : NSObject
- (SPIMessage *)toMessage;

@end

@interface SPILoginResponse : NSObject

@property (nonatomic, readonly) BOOL           isSuccess;
@property (nonatomic, readonly, copy) NSString *expires;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (BOOL)expiringSoon:(NSTimeInterval)serverTimeDelta;

@end
