//
//  SPIDeviceInfo.m
//  SPIClient-iOS
//
//  Created by Mike Gouline on 4/7/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIDeviceInfo.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>

@implementation SPIDeviceInfo

+ (NSDictionary *)getAppDeviceInfo {
    UIDevice *device = UIDevice.currentDevice;
    NSDictionary *bundleInfo = NSBundle.mainBundle.infoDictionary;
    
    return @{
             @"device_name": [device name],
             @"device_model": [NSString stringWithFormat:@"%@ (%@)", device.model, [SPIDeviceInfo getDeviceName]],
             @"device_system": [NSString stringWithFormat:@"%@ %@", device.systemName, device.systemVersion],
             @"app_display_name": [bundleInfo objectForKey:@"CFBundleName"],
             @"app_bundle_id": [bundleInfo objectForKey:@"CFBundleIdentifier"],
             @"app_version": [bundleInfo objectForKey:@"CFBundleShortVersionString"],
             @"app_build": [bundleInfo objectForKey:@"CFBundleVersion"],
             };
}

+ (NSString *)getDeviceName {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

@end
