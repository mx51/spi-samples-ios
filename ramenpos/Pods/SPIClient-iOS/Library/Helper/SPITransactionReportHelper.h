//
//  SPITransactionReportHelper.h
//  SPIClient-iOS
//
//  Created by Doniyorjon Zuparov on 12/07/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIAnalyticsService.h"

@interface SPITransactionReportHelper : NSObject

+ (SPITransactionReport *)createTransactionReportEnvelope:(NSString *)posVendorId
                                               posVersion:(NSString *)posVersion
                                          libraryLanguage:(NSString *)libraryLanguage
                                           libraryVersion:(NSString *)libraryVersion
                                             serialNumber:(NSString *)serialNumber;

@end
