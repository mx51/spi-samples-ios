//
//  SPITenantsService.h
//  SPIClient-iOS
//
//  Created by mx51 on 25/02/21.
//  Copyright © 2021 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^SPITenantsResult)(NSArray *tenants);

@interface SPITenantsService : NSObject

- (void)retrieveTenants:(NSString *)posVendorId
                 apiKey:(NSString *)apiKey
            countryCode:(NSString *)countryCode
             completion:(SPITenantsResult)completion;

@end
