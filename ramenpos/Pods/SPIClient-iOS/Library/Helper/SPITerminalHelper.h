//
//  SPITerminalHelper.h
//  SPIClient-iOS
//
//  Created by Doniyorjon Zuparov on 26/07/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPITerminalHelper : NSObject

+ (BOOL)isPrinterAvailable:(NSString *)terminalModel;

@end
