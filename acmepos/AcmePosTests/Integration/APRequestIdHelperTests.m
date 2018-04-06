//
//  SPIRequestIdHelperTests.m
//  AcmePosTests
//
//  Created by Yoo-Jin Lee on 2017-11-26.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SPIRequestIdHelper.h"

@interface SPIRequestIdHelperTests : XCTestCase
@end

@implementation SPIRequestIdHelperTests

- (void)testId {
    XCTAssertNotEqualObjects([SPIRequestIdHelper idForString:@""],    [SPIRequestIdHelper idForString:@""]);
    XCTAssertNotEqualObjects([SPIRequestIdHelper idForString:@"3"],   [SPIRequestIdHelper idForString:@"3"]);
    XCTAssertNotEqualObjects([SPIRequestIdHelper idForString:@"a"],   [SPIRequestIdHelper idForString:@"a"]);
    XCTAssertNotEqualObjects([SPIRequestIdHelper idForString:@"abc"], [SPIRequestIdHelper idForString:@"abc"]);
}

@end
