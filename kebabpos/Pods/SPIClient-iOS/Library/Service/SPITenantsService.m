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
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:tenantServiceUrl]];
    [request setTimeoutInterval:connectionTimeout];
    [request setHTTPMethod:@"GET"];
    
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
        
        NSError *jsonError = nil;
        NSData *jsonData = [decodedString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];

        if (jsonError) {
            completion(nil);
            return;
        }
        
        NSArray *tenantsList = jsonDictionary[@"data"];
        completion(tenantsList);
    }];
    [task resume];
}

@end
