//
//  SPIDeviceService.m
//  SPIClient-iOS
//
//  Created by Metin Avci on 26/11/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIDeviceService.h"

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
            for (NSString* key in JSONDictionary) {
                if ([key  isEqual: @"ip"]) {
                    _address = [JSONDictionary valueForKey:key];
                } else if ([key  isEqual: @"last_updated"]) {
                    _lastUpdated = [JSONDictionary valueForKey:key];
                }
            }
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone { 
    SPIDeviceAddressStatus *state = [SPIDeviceAddressStatus new];
    state.address = self.address;
    state.lastUpdated = self.lastUpdated;
    return state;
}

@end

@implementation SPIDeviceService : NSObject

- (SPIDeviceAddressStatus *) retrieveServiceWithSerialNumber:(NSString *)serialNumber
                                                      apiKey:(NSString *)apiKey
                                                acquirerCode:(NSString *)acquirerCode
                                                  isTestMode:(BOOL)isTestMode {
    NSString *deviceAddressUrl;
    
    if (isTestMode) {
        deviceAddressUrl = [NSString stringWithFormat: @"https://device-address-api-sb.%@.msp.assemblypayments.com/v1/%@/ip", acquirerCode, serialNumber];
    } else {
        deviceAddressUrl = [NSString stringWithFormat: @"https://device-address-api.%@.msp.assemblypayments.com/v1/%@/ip", acquirerCode, serialNumber];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setValue:apiKey forHTTPHeaderField:@"ASM-MSP-DEVICE-ADDRESS-API-KEY"];
    [request setURL:[NSURL URLWithString:deviceAddressUrl]];
    
    NSError *error = nil;
    NSHTTPURLResponse *responseCode = nil;
    
    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
    
    if([responseCode statusCode] != 200){
        NSLog(@"Error getting %@, HTTP status code %li", deviceAddressUrl, (long)[responseCode statusCode]);
        return nil;
    }
    
    return [[SPIDeviceAddressStatus alloc] initWithJSONString:[[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding]] ;
}

@end
