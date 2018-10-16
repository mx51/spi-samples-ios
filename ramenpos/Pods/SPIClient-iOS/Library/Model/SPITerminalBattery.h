//
//  SPITerminalBattery.h
//  SPIClient-iOS
//
//  Created by Metin Avci on 24/9/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"

@interface SPITerminalBattery : NSObject

@property (nonatomic, readonly, strong) NSString *batteryLevel;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end
