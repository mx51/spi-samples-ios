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

@interface SPIDeviceService : NSObject

- (SPIDeviceAddressStatus *) retrieveServiceWithSerialNumber:(NSString *)serialNumber
                                                      apiKey:(NSString *)apiKey
                                                acquirerCode:(NSString *)acquirerCode
                                                  isTestMode:(BOOL)isTestMode;

@end
