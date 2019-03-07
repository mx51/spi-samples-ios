//
//  SPIPurchaseHelper.h
//  SPIClient-iOS
//
//  Created by Amir Kamali on 31/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPITransaction.h"
#import <Foundation/Foundation.h>

@interface SPIPurchaseHelper : NSObject

+ (SPIPurchaseRequest *)createPurchaseRequest:(NSInteger)amountCents
                                   purchaseId:(NSString *)purchaseId;

+ (SPIPurchaseRequest *)createPurchaseRequest:(NSString *)posRefId
                               purchaseAmount:(NSInteger)purchaseAmount
                                    tipAmount:(NSInteger)tipAmount
                                   cashAmount:(NSInteger)cashAmount
                             promptForCashout:(BOOL)promptForCashout;

+ (SPIPurchaseRequest *)createPurchaseRequest:(NSString *)posRefId
                               purchaseAmount:(NSInteger)purchaseAmount
                                    tipAmount:(NSInteger)tipAmount
                                   cashAmount:(NSInteger)cashAmount
                             promptForCashout:(BOOL)promptForCashout
                              surchargeAmount:(NSInteger)surchargeAmount;

+ (SPIRefundRequest *)createRefundRequest:(NSInteger)amountCents
                               purchaseId:(NSString *)purchaseId;

+ (SPIRefundRequest *)createRefundRequest:(NSInteger)amountCents
                               purchaseId:(NSString *)purchaseId
               suppressMerchantPassword:(BOOL)suppressMerchantPassword;

@end
