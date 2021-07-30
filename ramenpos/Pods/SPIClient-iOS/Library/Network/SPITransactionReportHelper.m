//
//  TransactionReportHelper.m
//  SPIClient-iOS
//
//  Created by Doniyorjon Zuparov on 12/07/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPITransactionReportHelper.h"


@implementation SPITransactionReportHelper

+ (SPITransactionReport *)createTransactionReportEnvelope:(NSString *)posVendorId
                                               posVersion:(NSString *)posVersion
                                          libraryLanguage:(NSString *)libraryLanguage
                                           libraryVersion:(NSString *)libraryVersion
                                             serialNumber:(NSString *)serialNumber {
    
    SPITransactionReport *transactionReport = [SPITransactionReport new];
    transactionReport.posVendorId = posVendorId;
    transactionReport.posVersion = posVersion;
    transactionReport.libraryLanguage = libraryLanguage;
    transactionReport.libraryVersion = libraryVersion;
    transactionReport.serialNumber = serialNumber;
    
    return transactionReport;
}

@end
