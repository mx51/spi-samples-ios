//
//  SPITerminalHelper.m
//  SPIClient-iOS
//
//  Created by Doniyorjon Zuparov on 26/07/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPITerminalHelper.h"

@implementation SPITerminalHelper

+ (BOOL)isPrinterAvailable:(NSString *)terminalModel {
    // Terminal model strings
    NSArray *terminalsWithoutPrinter = [NSArray arrayWithObjects: @"E355", nil];
    
    if ([terminalsWithoutPrinter containsObject: terminalModel]) {
        return false;
    }
    
    return true;
    
}

@end
