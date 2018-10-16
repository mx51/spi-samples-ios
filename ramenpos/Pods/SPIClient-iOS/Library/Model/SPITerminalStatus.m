//
//  SPITerminalStatus.m
//  Pods-KebabPos
//
//  Created by Metin Avci on 24/9/18.
//

#import "SPITerminalStatus.h"
#import "SPIRequestIdHelper.h"

@implementation SPITerminalStatusRequest

- (instancetype)init{
    
    self = [super init];
    
    if (self) {
        _infoId = [SPIRequestIdHelper idForString:@"trmnl"];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.infoId
                                       eventName:SPITerminalStatusRequestKey
                                            data:@{}
                                 needsEncryption:true];
}

@end

@implementation SPITerminalStatusResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _isSuccess = [message isSuccess];
    }
    
    return self;
}

- (NSString *)getStatus {
    return [self.message getDataStringValue:@"status"];
}

- (NSString *)getBatteryLevel {
    return [self.message getDataStringValue:@"battery_level"];
}

- (BOOL)getCharging {
    return [self.message getDataBoolValue:@"charging" defaultIfNotFound:false];
}

@end
