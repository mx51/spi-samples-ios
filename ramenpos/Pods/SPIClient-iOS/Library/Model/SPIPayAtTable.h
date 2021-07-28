//
//  SPIPayAtTable.h
//  SPIClient-iOS
//
//  Created by Amir Kamali on 20/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import "SPIMessage.h"
#import "SPITransaction.h"
#import <Foundation/Foundation.h>

@class SPIClient;

typedef NS_ENUM(NSUInteger, SPIBillRetrievalResult) {
    BillRetrievalResultSuccess,
    BillRetrievalResultInvalidTableId,
    BillRetrievalResultInvalidBillId,
    BillRetrievalResultInvalidOperatorId,
};

typedef NS_ENUM(NSUInteger, SPIPaymentType) {
    SPIPaymentTypeCard,
    SPIPaymentTypeCash,
};

@interface SPIPaymentHistoryEntry : NSObject

@property (nonatomic, retain) NSString *paymentType;
@property (nonatomic, retain) NSDictionary *paymentSummary;

- (instancetype)initWithDictionary:(NSDictionary *)data;

- (NSDictionary *)toJsonObject;

- (NSString *)getTerminalRefId;

@end

/**
 * This class represents the BillDetails that the POS will be asked for
 * throughout a PayAtTable flow.
 */
@interface SPIBillStatusResponse : NSObject

/// Set this Error accordingly if you are not able to return the BillDetails
/// that were asked from you.
@property (nonatomic) SPIBillRetrievalResult result;

/**
 * This is a unique identifier that you assign to each bill.
 * It might be for example, the timestamp of when the cover was opened.
 */
@property (nonatomic, retain) NSString *billId;

/**
 * This is the table id that this bill was for.
 * The waiter will enter it on the Eftpos at the start of the PayAtTable flow
 * and the Eftpos will retrieve the bill using the table id.
 */
@property (nonatomic, retain) NSString *tableId;
@property (nonatomic, retain) NSString *operatorId;

/**
 * Your POS is required to persist some state on behalf of the Eftpos so the
 * Eftpos can recover state. It is just a piece of string that you save against
 * your billId. WHenever you're asked for BillDetails, make sure you return this
 * piece of data if you have it.
 */
@property (nonatomic, retain) NSString *billData;

/// The total amount on this bill, in cents.
@property (nonatomic) NSInteger totalAmount;

/// The currently outsanding amount on this bill, in cents.
@property (nonatomic) NSInteger outstandingAmount;

- (NSArray<SPIPaymentHistoryEntry *> *)getBillPaymentHistory;

+ (NSString *)toBillData:(NSArray<SPIPaymentHistoryEntry *> *)ph;

- (SPIMessage *)toMessage:(NSString *)messageId;

@end

@interface SPIOpenTablesEntry : NSObject

@property (nonatomic, copy) NSString *tableId;
@property (nonatomic, copy) NSString *label;
@property (nonatomic) NSInteger outstandingAmount;

- (instancetype)initWithDictionary:(NSDictionary *)data;

- (NSDictionary *)toJsonObject;

@end

@interface SPIGetOpenTablesResponse : NSObject

@property (nonatomic, copy) NSMutableArray<SPIOpenTablesEntry *> *openTablesEntries;

- (NSMutableArray<SPIOpenTablesEntry *> *)getOpenTables;

- (SPIMessage *)toMessage:(NSString *)messageId;

@end

@interface SPIBillPayment : NSObject

@property (nonatomic, retain) NSString *billId;
@property (nonatomic, retain) NSString *tableId;
@property (nonatomic, retain) NSString *operatorId;
@property (nonatomic) SPIPaymentType paymentType;
@property (nonatomic) NSInteger purchaseAmount;
@property (nonatomic) NSInteger tipAmount;
@property (nonatomic) NSInteger surchargeAmount;
@property (nonatomic, readonly, copy) SPIPurchaseResponse *purchaseResponse;
@property (nonatomic) BOOL paymentFlowStarted;

- (instancetype)initWithMessage:(SPIMessage *)message;

+ (NSString *)paymentTypeString:(SPIPaymentType)ptype;

@end

@interface SPIPayAtTableConfig : NSObject

@property (nonatomic) BOOL payAtTableEnabled;
@property (nonatomic) BOOL operatorIdEnabled;
@property (nonatomic) BOOL splitByAmountEnabled;
@property (nonatomic) BOOL equalSplitEnabled;
@property (nonatomic) BOOL tippingEnabled;
@property (nonatomic) BOOL summaryReportEnabled;
@property (nonatomic, copy) NSString *labelPayButton;
@property (nonatomic, copy) NSString *labelOperatorId;
@property (nonatomic, copy) NSString *labelTableId;
@property (nonatomic, copy) NSArray<NSString *> *allowedOperatorIds;
@property (nonatomic) BOOL tableRetrievalEnabled;

- (SPIMessage *)toMessage:(NSString *)messageId;

+ (SPIMessage *)featureDisableMessage:(NSString *)messageId;

@end

@protocol SPIPayAtTableDelegate <NSObject>

- (SPIBillStatusResponse *)payAtTableGetBillStatus:(NSString *)billId
                                           tableId:(NSString *)tableId
                                        operatorId:(NSString *)operatorId
                                paymentFlowStarted:(BOOL)paymentFlowStarted;

- (SPIBillStatusResponse *)payAtTableBillPaymentReceived:(SPIBillPayment *)billPayment
                                         updatedBillData:(NSString *)updatedBillData;

- (SPIGetOpenTablesResponse *)payAtTableGetOpenTables:(NSString *)operatorId;

- (void)payAtTableBillPaymentFlowEnded:(SPIMessage *)message;

@end

@interface SPIPayAtTable : NSObject

@property (nonatomic, readonly, copy) SPIPayAtTableConfig *config;
@property (nonatomic, weak) id<SPIPayAtTableDelegate> delegate;

- (instancetype)initWithClient:(SPIClient *)spi;

- (void)pushPayAtTableConfig;

- (void)handleGetTableConfig:(SPIMessage *)message;

- (void)handleGetBillDetailsRequest:(SPIMessage *)message;

- (void)handleBillPaymentAdvice:(SPIMessage *)message;

- (void)handleBillPaymentFlowEnded:(SPIMessage *)message;

- (void)handleGetOpenTablesRequest:(SPIMessage *)message;

@end

@interface SPIBillPaymentFlowEndedResponse : NSObject

@property (nonatomic, copy) NSString *billId;
@property (nonatomic, copy) NSString *tableId;
@property (nonatomic, copy) NSString *operatorId;
@property (nonatomic) NSInteger billTotalAmount;
@property (nonatomic) NSInteger billOutstandingAmount;
@property (nonatomic) NSInteger cardTotalCount;
@property (nonatomic) NSInteger cardTotalAmount;
@property (nonatomic) NSInteger cashTotalCount;
@property (nonatomic) NSInteger cashTotalAmount;

- (instancetype)initWithMessage:(SPIMessage *)message;

@end

@interface SPIBillPaymentFlowEndedAckRequest : NSObject

@property (nonatomic, copy) NSString *billId;
@property (nonatomic, copy) NSString *Id;

- (instancetype)initWithBillId:(NSString *)billId;

- (SPIMessage *)toMessage;

@end
