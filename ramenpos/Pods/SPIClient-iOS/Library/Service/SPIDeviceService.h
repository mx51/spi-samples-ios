//
//  SPIDeviceService.h
//  SPIClient-iOS
//
//  Created by Metin Avci on 26/11/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPIDeviceAddressStatus : NSObject <NSCopying>

@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *lastUpdated;

- (instancetype)initWithJSONString:(NSString *)JSONString;

@end

typedef void(^DeviceAddressStatusResult)(SPIDeviceAddressStatus *);

@interface SPIDeviceService : NSObject

- (void)retrieveServiceWithSerialNumber:(NSString *)serialNumber
                                 apiKey:(NSString *)apiKey
                           acquirerCode:(NSString *)acquirerCode
                             isTestMode:(BOOL)isTestMode
                             completion:(DeviceAddressStatusResult)completion;

@end
