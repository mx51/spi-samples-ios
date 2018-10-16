//
//  SPITerminalStatus.h
//  Pods
//
//  Created by Metin Avci on 24/9/18.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"

@interface SPITerminalStatusRequest : NSObject

@property (nonatomic, readonly, copy) NSString *infoId;

- (instancetype)init;

- (SPIMessage *)toMessage;

@end

@interface SPITerminalStatusResponse : NSObject

@property (nonatomic, readonly, strong) SPIMessage *message;
@property (nonatomic, readonly) BOOL isSuccess;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getStatus;

- (NSString *)getBatteryLevel;

- (BOOL)getCharging;

@end
