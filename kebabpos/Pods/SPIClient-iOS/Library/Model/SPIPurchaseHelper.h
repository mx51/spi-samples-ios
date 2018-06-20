//
//  SPIPurchaseHelper.h
//  SPIClient-iOS
//
//  Created by Amir Kamali on 31/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIPurchase.h"
#import <Foundation/Foundation.h>

@interface SPIPurchaseHelper : NSObject

+ (SPIPurchaseRequest *)createPurchaseRequest:(NSInteger)amountCents
                                   purchaseId:(NSString *)purchaseId;

+ (SPIPurchaseRequest *)createPurchaseRequestV2:(NSString *)posRefId
                                 purchaseAmount:(NSInteger)purchaseAmount
                                      tipAmount:(NSInteger)tipAmount
                                     cashAmount:(NSInteger)cashAmount
                               promptForCashout:(BOOL)promptForCashout;

+ (SPIRefundRequest *)createRefundRequest:(NSInteger)amountCents
                               purchaseId:(NSString *)purchaseId;

@end
