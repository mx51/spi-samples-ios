//
//  SPITenantsService.m
//  SPIClient-iOS
//
//  Created by mx51 on 25/02/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPITenantsService.h"

static NSTimeInterval connectionTimeout = 8; // HTTP connection timeout

@implementation SPITenantsService : NSObject

- (void)retrieveTenants:(NSString *)posVendorId
                 apiKey:(NSString *)apiKey
            countryCode:(NSString *)countryCode
             completion:(SPITenantsResult)completion {
    NSString *tenantServiceUrl = [NSString stringWithFormat: @"https://spi.integration.mspenv.io/tenants?country-code=%@&pos-vendor-id=%@&api-key=%@", countryCode, posVendorId, apiKey];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setTimeoutInterval:connectionTimeout];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:tenantServiceUrl]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable urlResponse, NSError * _Nullable error) {
        NSString *decodedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        if (error) {
            NSLog(@"Error getting %@: %@", tenantServiceUrl, error);
            completion(nil);
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse;
        if ([httpResponse statusCode] != 200){
            NSLog(@"Error getting %@, HTTP status code %li", tenantServiceUrl, (long)[httpResponse statusCode]);
            
            completion(nil);
            return;
        }
        
        NSError *JSONError = nil;
        NSData *JSONData = [decodedString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *JSONDictionary = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&JSONError];

        if (JSONError) {
            completion(nil);
            return;
        }
        
        NSArray *tenantsList = JSONDictionary[@"data"];
        completion(tenantsList);
    }];
    [task resume];
}

@end
