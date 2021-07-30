//
//  SPIAnalyticsService.m
//  SPIClient-iOS
//
//  Created by Doniyorjon Zuparov on 09/07/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIAnalyticsService.h"
#import "SPILogger.h"

@implementation SPITransactionReport

- (NSString *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    if (self.posVendorId) {
        [dict setObject:self.posVendorId forKey:@"pos_vendor_id"];
    }
    
    if (self.posVersion) {
        [dict setObject:self.posVersion forKey:@"pos_version"];
    }
    
    if (self.libraryLanguage) {
        [dict setObject:self.libraryLanguage forKey:@"library_language"];
    }
    
    if (self.libraryVersion) {
        [dict setObject:self.libraryVersion forKey:@"library_version"];
    }
    
    if (self.posRefId) {
        [dict setObject:self.posRefId forKey:@"pos_ref_id"];
    }
    
    if (self.serialNumber) {
        [dict setObject:self.serialNumber forKey:@"serial_number"];
    }
    
    if (self.event) {
        [dict setObject:self.event forKey:@"event"];
    }
    
    if (self.txType) {
        [dict setObject:self.txType forKey:@"tx_type"];
    }
    
    if (self.txResult) {
        [dict setObject:self.txResult forKey:@"tx_result"];
    }
    
    if (self.txStartTime) {
        [dict setObject:self.txStartTime forKey:@"tx_start_ts_ms"];
    }
    
    if (self.txEndTime) {
        [dict setObject:self.txEndTime forKey:@"tx_end_ts_ms"];
    }
    
    if (self.durationMs) {
        [dict setObject:self.durationMs forKey:@"duration_ms"];
    }
    
    if (self.currentFlow) {
        [dict setObject:self.currentFlow forKey:@"current_flow"];
    }
    
    if (self.currentTxFlowState) {
        [dict setObject:self.currentTxFlowState forKey:@"current_tx_flow_state"];
    }
    
    if (self.currentStatus) {
        [dict setObject:self.currentStatus forKey:@"current_status"];
    }
    
    return dict.copy;
}

@end

@implementation SPIAnalyticsService

+ (void)reportTransaction:(SPITransactionReport *)transactionReport
                   apiKey:(NSString *)apiKey
             acquirerCode:(NSString *)acquirerCode
               isTestMode:(BOOL)isTestMode {
    
    NSString *transactionServiceUriBase = isTestMode ? @"https://spi-analytics-api-sb.%@.mspenv.io/v1/report-transaction" : @"https://spi-analytics-api.%@.mspenv.io/v1/report-transaction";
    
    NSString *transactionServiceUri = [NSString stringWithFormat:transactionServiceUriBase, acquirerCode];
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:defaultConfigObject];
    
    NSURL *url = [NSURL URLWithString:transactionServiceUri];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    NSString *data = [transactionReport toJson];
    
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:0
                                                         error:&jsonError];
    
    if (jsonError) {
        SPILog(@"ERROR: Transaction report serialization error: %@", jsonError);
        return;
    }
    
    [urlRequest setHTTPMethod:@"POST"];
    
    [urlRequest setHTTPBody:jsonData];
    
    [urlRequest setAllHTTPHeaderFields:@{
                @"ASM-MSP-DEVICE-ADDRESS-API-KEY": apiKey,
                @"Content-Type": @"application/json"
    }];
    
    NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            SPILog(@"Error reporting to %@: %@", transactionServiceUri, error);
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if ([httpResponse statusCode] != 200){
            NSLog(@"Error reporting to %@, HTTP status code %li", transactionServiceUri, (long)[httpResponse statusCode]);
            return;
        }
    }];
    
    [dataTask resume];
}

@end
