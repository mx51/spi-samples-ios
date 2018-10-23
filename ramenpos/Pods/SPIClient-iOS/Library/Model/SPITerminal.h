//
//  SPITerminalStatus.h
//  Pods
//
//  Created by Metin Avci on 24/9/18.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"

@interface SPITerminalBattery : NSObject

@property (nonatomic, readonly, strong) NSString *batteryLevel;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end

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

@interface SPITerminalConfigurationRequest : NSObject

@property (nonatomic, readonly, copy) NSString *infoId;

- (instancetype)init;

- (SPIMessage *)toMessage;

@end

@interface SPITerminalConfigurationResponse : NSObject

@property (nonatomic, readonly, strong) SPIMessage *message;
@property (nonatomic, readonly) BOOL isSuccess;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getCommsSelected;

- (NSString *)getMerchantId;

- (NSString *)getPAVersion;

- (NSString *)getPaymentInterfaceVersion;

- (NSString *)getPluginVersion;

- (NSString *)getSerialNumber;

- (NSString *)getTerminalId;

- (NSString *)getTerminalModel;

@end
