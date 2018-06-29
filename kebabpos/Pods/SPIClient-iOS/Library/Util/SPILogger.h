//
//  SPILogger.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const SPILogNotificationKey;

// Swift cannot call Variadic function
void SPILogMsg(NSString *format);

void SPILog(NSString *format, ...);
