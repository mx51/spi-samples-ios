//
//  SPIPurchaseHelper.m
//  SPIClient-iOS
//
//  Created by Amir Kamali on 31/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIPurchaseHelper.h"

@implementation SPIPurchaseHelper
+ (SPIPurchaseRequest *)createPurchaseRequest:(NSInteger)amountCents
                                   purchaseId:(NSString *)purchaseId {
    return [[SPIPurchaseRequest alloc] initWithAmountCents:amountCents
                                                  posRefId:purchaseId];
}

+ (SPIPurchaseRequest *)createPurchaseRequestV2:(NSString *)posRefId
                                 purchaseAmount:(NSInteger)purchaseAmount
                                      tipAmount:(NSInteger)tipAmount
                                     cashAmount:(NSInteger)cashAmount
                               promptForCashout:(BOOL)promptForCashout {
    SPIPurchaseRequest *request = [[SPIPurchaseRequest alloc]
                                   initWithAmountCents:purchaseAmount
                                           posRefId:posRefId];
    request.cashoutAmount = cashAmount;
    request.tipAmount = tipAmount;
    request.promptForCashout = promptForCashout;
    return request;
}

+ (SPIRefundRequest *)createRefundRequest:(NSInteger)amountCents
                               purchaseId:(NSString *)purchaseId {
    return [[SPIRefundRequest alloc] initWithPosRefId:purchaseId
                                          amountCents:amountCents];
}

@end
