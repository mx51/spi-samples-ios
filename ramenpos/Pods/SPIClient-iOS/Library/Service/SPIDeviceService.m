//
//  SPIDeviceService.m
//  SPIClient-iOS
//
//  Created by Metin Avci on 26/11/18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIDeviceService.h"

static NSTimeInterval connectionTimeout = 8; // How long do we wait for a pong to come back

@implementation SPIDeviceAddressStatus : NSObject

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (instancetype)initWithJSONString:(NSString *)JSONString
{
    self = [super init];
    
    if (self) {
        NSError *error = nil;
        NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *JSONDictionary = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&error];
        
        if (!error && JSONDictionary) {
            _address = JSONDictionary[@"ip"];
            _lastUpdated = JSONDictionary[@"last_updated"];
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone { 
    SPIDeviceAddressStatus *state = [SPIDeviceAddressStatus new];
    state.address = self.address;
    state.lastUpdated = self.lastUpdated;
    state.deviceAddressResponseCode = self.deviceAddressResponseCode;
    return state;
}

@end

@implementation SPIDeviceService : NSObject

- (void)retrieveServiceWithSerialNumber:(NSString *)serialNumber
                                 apiKey:(NSString *)apiKey
                           acquirerCode:(NSString *)acquirerCode
                             isTestMode:(BOOL)isTestMode
                             completion:(DeviceAddressStatusResult)completion {
    NSString *deviceAddressUrl;
    SPIDeviceAddressStatus *deviceAddressStatus = [[SPIDeviceAddressStatus alloc] init];
    
    if (isTestMode) {
        deviceAddressUrl = [NSString stringWithFormat: @"https://device-address-api-sb.%@.msp.assemblypayments.com/v1/%@/ip", acquirerCode, serialNumber];
    } else {
        deviceAddressUrl = [NSString stringWithFormat: @"https://device-address-api.%@.msp.assemblypayments.com/v1/%@/ip", acquirerCode, serialNumber];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setTimeoutInterval:connectionTimeout];
    [request setHTTPMethod:@"GET"];
    [request setValue:apiKey forHTTPHeaderField:@"ASM-MSP-DEVICE-ADDRESS-API-KEY"];
    [request setURL:[NSURL URLWithString:deviceAddressUrl]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable urlResponse, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error getting %@: %@", deviceAddressUrl, error);
            completion(nil);
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse;
        if ([httpResponse statusCode] != 200){
            NSLog(@"Error getting %@, HTTP status code %li", deviceAddressUrl, (long)[httpResponse statusCode]);
            deviceAddressStatus.responseCode = [httpResponse statusCode];
            completion([deviceAddressStatus initWithJSONString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
            return;
        }
        
        completion([deviceAddressStatus initWithJSONString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
    }];
    [task resume];
}

@end
