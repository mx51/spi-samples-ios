//
//  SPITerminalBattery.m
//  SPIClient-iOS
//
//  Created by Metin Avci on 24/9/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPITerminalBattery.h"

@implementation SPITerminalBattery : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _batteryLevel = [message getDataStringValue:@"battery_level"];
    }
    
    return self;
}

@end
