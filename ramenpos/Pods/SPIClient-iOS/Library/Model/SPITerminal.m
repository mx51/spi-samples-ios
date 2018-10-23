//
//  SPITerminalStatus.m
//  Pods-KebabPos
//
//  Created by Metin Avci on 24/9/18.
//

#import "SPITerminal.h"
#import "SPIRequestIdHelper.h"

@implementation SPITerminalBattery : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _batteryLevel = [message getDataStringValue:@"battery_level"];
    }
    
    return self;
}

@end

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

@implementation SPITerminalConfigurationRequest

- (instancetype)init{
    
    self = [super init];
    
    if (self) {
        _infoId = [SPIRequestIdHelper idForString:@"trmnlcnfg"];
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.infoId
                                       eventName:SPITerminalConfigurationRequestKey
                                            data:@{}
                                 needsEncryption:true];
}

@end

@implementation SPITerminalConfigurationResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _isSuccess = [message isSuccess];
    }
    
    return self;
}

- (NSString *)getCommsSelected {
    return [self.message getDataStringValue:@"comms_selected"];
}

- (NSString *)getMerchantId {
    return [self.message getDataStringValue:@"merchant_id"];
}

- (NSString *)getPAVersion {
    return [self.message getDataStringValue:@"pa_version"];
}

- (NSString *)getPaymentInterfaceVersion {
    return [self.message getDataStringValue:@"payment_interface_version"];
}

- (NSString *)getPluginVersion {
    return [self.message getDataStringValue:@"plugin_version"];
}

- (NSString *)getSerialNumber {
    return [self.message getDataStringValue:@"serial_number"];
}

- (NSString *)getTerminalId {
    return [self.message getDataStringValue:@"terminal_id"];
}

- (NSString *)getTerminalModel {
    return [self.message getDataStringValue:@"terminal_model"];
}

@end
