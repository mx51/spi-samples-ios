//
//  SPIPurchaseHelper.m
//  SPIClient-iOS
//
//  Created by Amir Kamali on 31/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import "SPIPurchaseHelper.h"

@implementation SPIPurchaseHelper

+ (SPIPurchaseRequest *)createPurchaseRequest:(NSInteger)amountCents purchaseId:(NSString *)purchaseId {
    return [SPIPurchaseHelper createPurchaseRequest:purchaseId
                                     purchaseAmount:amountCents
                                          tipAmount:0
                                         cashAmount:0
                                   promptForCashout:false];
}

+ (SPIPurchaseRequest *)createPurchaseRequest:(NSString *)posRefId
                               purchaseAmount:(NSInteger)purchaseAmount
                                    tipAmount:(NSInteger)tipAmount
                                   cashAmount:(NSInteger)cashAmount
                             promptForCashout:(BOOL)promptForCashout {
    return [SPIPurchaseHelper createPurchaseRequest:posRefId
                                     purchaseAmount:purchaseAmount
                                          tipAmount:tipAmount cashAmount:cashAmount
                                   promptForCashout:promptForCashout
                                    surchargeAmount:0];
}

+ (SPIPurchaseRequest *)createPurchaseRequest:(NSString *)posRefId
                               purchaseAmount:(NSInteger)purchaseAmount
                                    tipAmount:(NSInteger)tipAmount
                                   cashAmount:(NSInteger)cashAmount
                             promptForCashout:(BOOL)promptForCashout
                              surchargeAmount:(NSInteger)surchargeAmount {
    
    SPIPurchaseRequest *request = [[SPIPurchaseRequest alloc] initWithAmountCents:purchaseAmount
                                                                         posRefId:posRefId];
    request.cashoutAmount = cashAmount;
    request.tipAmount = tipAmount;
    request.promptForCashout = promptForCashout;
    request.surchargeAmount = surchargeAmount;
    return request;
}

+ (SPIRefundRequest *)createRefundRequest:(NSInteger)amountCents
                               purchaseId:(NSString *)purchaseId {
    return [SPIPurchaseHelper createRefundRequest:amountCents
                                       purchaseId:purchaseId
                         suppressMerchantPassword:false];
}

+ (SPIRefundRequest *)createRefundRequest:(NSInteger)amountCents
                               purchaseId:(NSString *)purchaseId
                 suppressMerchantPassword:(BOOL)suppressMerchantPassword {
    SPIRefundRequest *request =  [[SPIRefundRequest alloc] initWithPosRefId:purchaseId
                                                                amountCents:amountCents];
    request.suppressMerchantPassword = suppressMerchantPassword;
    return request;
}

@end
