//
//  SPIPosInfo.h
//  SPIClient-iOS
//
//  Created by Mike Gouline on 3/7/18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIMessage.h"

@interface SPISetPosInfoRequest : NSObject

@property (nonatomic, readonly, copy) NSString *infoId;
@property (nonatomic, readonly, copy) NSString *version;
@property (nonatomic, readonly, copy) NSString *vendorId;
@property (nonatomic, readonly, copy) NSString *libraryLanguage;
@property (nonatomic, readonly, copy) NSString *libraryVersion;
@property (nonatomic, readonly, copy) NSDictionary *otherInfo;

- (instancetype)initWithVersion:(NSString *)version
                       vendorId:(NSString *)vendorId
                libraryLanguage:(NSString *)libraryLanguage
                 libraryVersion:(NSString *)libraryVersion
                      otherInfo:(NSDictionary *)otherInfo;

- (SPIMessage *)toMessage;

@end

@interface SPISetPosInfoResponse : NSObject

@property (nonatomic, readonly, strong) SPIMessage *message;
@property (nonatomic, readonly) BOOL isSuccess;

- (instancetype)initWithMessage:(SPIMessage *)message;

- (NSString *)getErrorReason;

- (NSString *)getErrorDetail;

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute;

@end
