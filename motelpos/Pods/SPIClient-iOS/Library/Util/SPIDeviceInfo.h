//
//  SPIDeviceInfo.h
//  SPIClient-iOS
//
//  Created by Mike Gouline on 4/7/18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPIDeviceInfo : NSObject

// Analytics information about device and app.
+ (NSDictionary *)getAppDeviceInfo;

// Hardware device name.
+ (NSString *)getDeviceName;

@end
