//
//  SPIPosInfo.m
//  SPIClient-iOS
//
//  Created by Mike Gouline on 3/7/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIPosInfo.h"
#import "SPIRequestIdHelper.h"

@implementation SPISetPosInfoRequest

- (instancetype)initWithVersion:(NSString *)version
                       vendorId:(NSString *)vendorId
                libraryLanguage:(NSString *)libraryLanguage
                 libraryVersion:(NSString *)libraryVersion
                      otherInfo:(NSDictionary *)otherInfo {
    
    self = [super init];
    
    if (self) {
        _infoId = [SPIRequestIdHelper idForString:@"posinfo"];
        _version = version;
        _vendorId = vendorId;
        _libraryLanguage = libraryLanguage;
        _libraryVersion = libraryVersion;
        _otherInfo = otherInfo;
    }
    
    return self;
}

- (SPIMessage *)toMessage {
    return [[SPIMessage alloc] initWithMessageId:self.infoId
                                       eventName:SPISetPosInfoRequestKey
                                            data:@{
                                                   @"pos_version": self.version,
                                                   @"pos_vendor_id": self.vendorId,
                                                   @"library_language": self.libraryLanguage,
                                                   @"library_version": self.libraryVersion,
                                                   @"other_info": self.otherInfo
                                                   }
                                 needsEncryption:true];
}

@end

@implementation SPISetPosInfoResponse : NSObject

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _message = message;
        _isSuccess = [message isSuccess];
    }
    
    return self;
}

- (NSString *)getErrorReason {
    return [self.message getDataStringValue:@"error_reason"];
}

- (NSString *)getErrorDetail {
    return [self.message getDataStringValue:@"error_detail"];
}

- (NSString *)getResponseValueWithAttribute:(NSString *)attribute {
    return [self.message getDataStringValue:attribute];
}

@end
