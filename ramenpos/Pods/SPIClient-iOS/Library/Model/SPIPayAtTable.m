//
//  SPIPayAtTable.m
//  SPIClient-iOS
//
//  Created by Amir Kamali on 20/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

#import "SPIPayAtTable.h"
#import "NSString+Util.h"
#import "SPILogger.h"
#import "SPIClient.h"
#import "SPIClient+Internal.h"
#import "SPIRequestIdHelper.h"

@implementation SPIBillStatusResponse

- (NSArray<SPIPaymentHistoryEntry *> *)getBillPaymentHistory {
    if (_billData == nil || [_billData isEqualToString:@""]) {
        return [[NSArray alloc] init];
    }
    
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:_billData options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    SPILog(@"Decoded payment history: %@", decodedString);
    
    NSError *jsonError = nil;
    NSDictionary *jsonData  = [NSJSONSerialization JSONObjectWithData:decodedData options:NSJSONReadingAllowFragments error:&jsonError];
    
    if (jsonError) {
        SPILog(@"ERROR: Payment history decoding error: %@", jsonError);
        return [[NSArray alloc] init];
    }
    
    NSMutableArray *paymentHistory = [[NSMutableArray alloc] init];
    for (NSDictionary * historyValue in jsonData) {
        SPIPaymentHistoryEntry *historyItem = [[SPIPaymentHistoryEntry alloc] initWithDictionary:historyValue];
        [paymentHistory addObject:historyItem];
    }
    
    return [paymentHistory copy];
}


+ (NSString *)toBillData:(NSArray<SPIPaymentHistoryEntry *> *)ph {
    if (ph.count < 1) {
        return @"";
    }
    
    NSError *writeError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:ph options:NSJSONWritingPrettyPrinted error:&writeError];
    return [jsonData base64EncodedStringWithOptions:0];
}

- (SPIMessage *)toMessage:(NSString *)messageId {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    BOOL success = _result == BillRetrievalResultSuccess;
    [data setValue:@(success) forKey:@"success"];
    if (_billId.length > 0) {
        [data setValue:_billId forKey:@"bill_id"];
    }
    if (_tableId.length > 0) {
        [data setValue:_tableId forKey:@"table_id"];
    }
    if (_result == BillRetrievalResultSuccess) {
        [data setValue:@(_totalAmount) forKey:@"bill_total_amount"];
        [data setValue:@(_outstandingAmount) forKey:@"bill_outstanding_amount"];
        
        NSMutableArray<SPIPaymentHistoryEntry*> *existingHistoryJson = [[NSMutableArray alloc] init];
        for (SPIPaymentHistoryEntry *response in self.getBillPaymentHistory) {
            [existingHistoryJson addObjectsFromArray:[NSArray arrayWithObject:response.toJsonObject]];
        }
        
        [data setObject:existingHistoryJson forKey:@"bill_payment_history"];
    } else {
        [data setValue:[NSNumber numberWithInt:_result].stringValue forKey:@"error_reason" ];
        [data setValue:[NSNumber numberWithInt:_result].stringValue forKey:@"error_detail"];
    }
    
    return [[SPIMessage alloc] initWithMessageId:messageId eventName:SPIPayAtTableBillDetailsKey data:data needsEncryption:true];
}

@end

@implementation SPIPaymentHistoryEntry

- (instancetype)initWithDictionary:(NSDictionary *)data {
    _paymentType = [data valueForKey:@"payment_type"];
    _paymentSummary = [data valueForKey:@"payment_summary"];
    return self;
}

- (NSString *)getTerminalRefId {
    if ([_paymentSummary.allKeys containsObject:@"terminal_ref_id"]) {
        return _paymentSummary[@"terminal_ref_id"];
    }
    return nil;
}

- (NSDictionary *)toJsonObject {
    NSMutableDictionary * data = [[NSMutableDictionary alloc] init];
    [data setValue:_paymentType forKey:@"payment_type"];
    [data setValue:_paymentSummary forKey:@"payment_summary"];
    return data;
}

@end

@interface SPIBillPayment()

@property (nonatomic,retain) SPIMessage *incomingAdvice;

@end

@implementation SPIBillPayment

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _incomingAdvice = message;
        _billId = [_incomingAdvice getDataStringValue:@"bill_id"];
        _tableId = [_incomingAdvice getDataStringValue:@"table_id"];
        _operatorId = [_incomingAdvice getDataStringValue:@"operator_id"];
        
        
        NSString *paymentType = [_incomingAdvice getDataStringValue:@"payment_type"];
        NSString *cardPaymentType = [SPIBillPayment paymentTypeString:SPIPaymentTypeCard].lowercaseString;
        NSString *cashPaymentType = [SPIBillPayment paymentTypeString:SPIPaymentTypeCash].lowercaseString;
        
        if ([paymentType isEqualToString:cardPaymentType]) {
            _paymentType = SPIPaymentTypeCard;
        } else if ([paymentType isEqualToString:cashPaymentType]) {
            _paymentType = SPIPaymentTypeCash;
        }
        
        NSDictionary<NSString *,NSObject *> *data = (NSDictionary *)message.data[@"payment_details"];
        
        // this is when we ply the sub object "payment_details" into a purchase response for convenience.
        SPIMessage *purchaseMsg = [[SPIMessage alloc] initWithMessageId:message.mid eventName:@"payment_details" data:data needsEncryption:false];
        
        _purchaseResponse = [[SPIPurchaseResponse alloc] initWithMessage:purchaseMsg];
        _purchaseAmount = [_purchaseResponse getPurchaseAmount];
        _tipAmount =  [_purchaseResponse getTipAmount];
        _surchargeAmount = [_purchaseResponse getSurchargeAmount];
    }
    
    return self;
}

+ (NSString *)paymentTypeString:(SPIPaymentType)ptype {
    NSString *result = nil;
    switch (ptype) {
            case SPIPaymentTypeCard:
            result = @"CARD";
            break;
            case SPIPaymentTypeCash:
            result =  @"CASH";
            break;
        default:
            result =  nil;
            break;
    }
    
    return result;
}

@end

@implementation SPIPayAtTableConfig

- (SPIMessage *)toMessage:(NSString *)messageId {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:[NSNumber numberWithBool:_payAtTableEnabled]  forKey:@"pay_at_table_enabled"];
    [data setValue:[NSNumber numberWithBool:_operatorIdEnabled] forKey:@"operator_id_enabled"];
    [data setValue:[NSNumber numberWithBool:_splitByAmountEnabled] forKey:@"split_by_amount_enabled"];
    [data setValue:[NSNumber numberWithBool:_equalSplitEnabled] forKey:@"equal_split_enabled"];
    [data setValue:[NSNumber numberWithBool:_tippingEnabled] forKey:@"tipping_enabled"];
    [data setValue:[NSNumber numberWithBool:_summaryReportEnabled] forKey:@"summary_report_enabled"];
    [data setValue:[NSString stringWithFormat:@"%@", _labelPayButton] forKey:@"pay_button_label"];
    [data setValue:[NSString stringWithFormat:@"%@",_labelOperatorId] forKey:@"operator_id_label"];
    [data setValue:[NSString stringWithFormat:@"%@",_labelTableId] forKey:@"table_id_label"];
    [data setValue:_allowedOperatorIds forKey:@"operator_id_list"];
    [data setValue:[NSNumber numberWithBool:_tableRetrievalEnabled] forKey:@"table_retrieval_enabled"];
    
    return [[SPIMessage alloc] initWithMessageId:messageId eventName:SPIPayAtTableSetTableConfigKey data:data needsEncryption:true];
}

+ (SPIMessage *)featureDisableMessage:(NSString *)messageId {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:@false forKey:@"pay_at_table_enabled"];
    
    return [[SPIMessage alloc] initWithMessageId:messageId eventName:SPIPayAtTableSetTableConfigKey data:data needsEncryption:true];
}

@end

@class SPIClient;

@interface SPIPayAtTable() {
    SPIClient *_spi;
}

@end

@implementation SPIPayAtTable

- (instancetype)initWithClient:(SPIClient *)spi {
    self = [super init];
    
    if (self) {
        _spi = spi;
        _config = [[SPIPayAtTableConfig alloc] init];
    }
    
    return self;
}

- (void)pushPayAtTableConfig {
    [_spi send:[_config toMessage:[SPIRequestIdHelper idForString:@"patconf"]]];
}

- (void)handleGetBillDetailsRequest:(SPIMessage *)message {
    NSString *operatorId = [message getDataStringValue:@"operator_id"];
    NSString *tableId = [message getDataStringValue:@"table_id"];
    BOOL paymentFlowStarted = [message getDataBoolValue:@"payment_flow_started" defaultIfNotFound:false];
    
    // Ask POS for Bill Details for this tableId, inluding encoded PaymentData
    SPIBillStatusResponse *billStatus = [_delegate payAtTableGetBillStatus:nil
                                                                   tableId:tableId
                                                                operatorId:operatorId
                                                        paymentFlowStarted:paymentFlowStarted];
    billStatus.tableId = tableId;
    if (billStatus.totalAmount <= 0) {
        SPILog(@"Table has 0 total amount. Not sending it to EFTPOS.");
        billStatus.result = BillRetrievalResultInvalidTableId;
    }
    [_spi send:[billStatus toMessage:message.mid]];
}

- (void)handleBillPaymentAdvice:(SPIMessage *)message {
    SPIBillPayment *billPayment = [[SPIBillPayment alloc] initWithMessage:message];
    
    // Ask POS for Bill Details, inluding encoded PaymentData
    SPIBillStatusResponse *existingBillStatus = [_delegate payAtTableGetBillStatus:billPayment.billId
                                                                           tableId:billPayment.tableId
                                                                        operatorId:billPayment.operatorId
                                                                paymentFlowStarted:billPayment.paymentFlowStarted];
    if (existingBillStatus.result != BillRetrievalResultSuccess) {
        SPILog(@"Could not retrieve bill status for payment advice. Sending error to EFTPOS.");
        [_spi send:[existingBillStatus toMessage:message.mid]];
    }
    
    // Let's add the new entry to the history
    NSMutableArray<SPIPaymentHistoryEntry*> *updatedHistoryEntries = [[NSMutableArray alloc] init];
    for (SPIPaymentHistoryEntry *response in existingBillStatus.getBillPaymentHistory) {
        if ([response.getTerminalRefId isEqualToString:billPayment.purchaseResponse.getTerminalReferenceId]) {
            // We have already processed this payment
            // Perhaps EFTPOS did get our acknowledgement.
            // Let's update EFTPOS.
            SPILog(@"Had already received this bill paymemnt advice from EFTPOS. Ignoring.");
            [_spi send:[existingBillStatus toMessage:message.mid]];
            return;
        }
        [updatedHistoryEntries addObjectsFromArray:[NSArray arrayWithObject:response.toJsonObject]];
    }
    
    SPIPaymentHistoryEntry *newPaymentEntry = [[SPIPaymentHistoryEntry alloc] init];
    newPaymentEntry.paymentType = [SPIBillPayment paymentTypeString:billPayment.paymentType].lowercaseString;
    newPaymentEntry.paymentSummary = [billPayment.purchaseResponse toPaymentSummary];
    [updatedHistoryEntries addObjectsFromArray:[NSArray arrayWithObject:newPaymentEntry.toJsonObject]];
    
    NSString *updatedBillData = [SPIBillStatusResponse toBillData:updatedHistoryEntries];
    
    // Advise POS of new payment against this bill, and the updated BillData to Save.
    SPIBillStatusResponse *updatedBillStatus = [_delegate payAtTableBillPaymentReceived:billPayment updatedBillData:updatedBillData];
    
    // Just in case client forgot to set these:
    updatedBillStatus.billId = billPayment.billId;
    updatedBillStatus.tableId = billPayment.tableId;
    
    if (updatedBillStatus.result != BillRetrievalResultSuccess) {
        SPILog(@"POS errored when being advised of payment. Letting EFTPOS know, and sending existing bill data.");
        updatedBillStatus.billData = existingBillStatus.billData;
    }else{
        updatedBillStatus.billData = updatedBillData;
    }
    
    [_spi send:[updatedBillStatus toMessage:message.mid]];
}

- (void)handleGetTableConfig:(SPIMessage *)message {
    [_spi send:[_config toMessage:message.mid]];
}

- (void)handleBillPaymentFlowEnded:(SPIMessage *)message {
    // bill payment flow has ended, we need to respond with an ack
    if (_spi.state.status == SPIStatusPairedConnected) {
        SPIBillPaymentFlowEndedResponse *response = [[SPIBillPaymentFlowEndedResponse alloc] initWithMessage:message];
        SPIBillPaymentFlowEndedAckRequest *request = [[SPIBillPaymentFlowEndedAckRequest alloc] initWithBillId:response.billId];
        [_spi send:[request toMessage]];
    }
    [_delegate payAtTableBillPaymentFlowEnded:message];
}

- (void)handleGetOpenTablesRequest:(SPIMessage *)message {
    NSString *operatorId = [message getDataStringValue:@"operator_id"];
    
    SPIGetOpenTablesResponse *openTablesResponse = [_delegate payAtTableGetOpenTables:operatorId];
    
    if (openTablesResponse.openTablesEntries.count <= 0) {
        SPILog(@"There is no open table.");
        openTablesResponse = [[SPIGetOpenTablesResponse alloc] init];
    }
    
    [_spi send:[openTablesResponse toMessage:message.mid]];
}

@end

@implementation SPIBillPaymentFlowEndedResponse

- (instancetype)initWithMessage:(SPIMessage *)message {
    self = [super init];
    
    if (self) {
        _billId = [message getDataStringValue:@"bill_id"];
        _tableId = [message getDataStringValue:@"table_id"];
        _operatorId = [message getDataStringValue:@"operator_id"];
        _billOutstandingAmount = [message getDataIntegerValue:@"bill_outstanding_amount"];
        _billTotalAmount = [message getDataIntegerValue:@"bill_total_amount"];
        _cardTotalCount = [message getDataIntegerValue:@"card_total_count"];
        _cardTotalAmount = [message getDataIntegerValue:@"card_total_amount"];
        _cashTotalCount = [message getDataIntegerValue:@"cash_total_count"];
        _cashTotalAmount = [message getDataIntegerValue:@"cash_total_amount"];
    }
    
    return self;
}

@end

@implementation SPIBillPaymentFlowEndedAckRequest

- (instancetype)initWithBillId:(NSString *)billId {
    self = [super init];
    
    if (self) {
        _billId = billId;
        _Id = @"";
    }
    return self;
}

- (SPIMessage *)toMessage {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:_billId forKey:@"bill_id"];
    
    return [[SPIMessage alloc] initWithMessageId:[SPIRequestIdHelper idForString:@"authad"]
                                       eventName:SPIPayAtTableBillPaymentFlowEndedAckKey
                                            data:data
                                 needsEncryption:true];
}


@end

@implementation SPIOpenTablesEntry

- (instancetype)initWithDictionary:(NSDictionary *)data {
    _tableId = [data valueForKey:@"table_id"];
    _label = [data valueForKey:@"label"];
    _outstandingAmount = [[data valueForKey:@"bill_outstanding_amount"] integerValue];
    return self;
}

- (NSDictionary *)toJsonObject {
    NSMutableDictionary * data = [[NSMutableDictionary alloc] init];
    [data setValue: _tableId forKey:@"table_id"];
    [data setValue: _label forKey:@"label"];
    [data setValue: @(_outstandingAmount) forKey:@"bill_outstanding_amount"];
    return data;
}

@end

@implementation SPIGetOpenTablesResponse

- (NSMutableArray<SPIOpenTablesEntry *> *)getOpenTables {
    NSMutableArray<SPIOpenTablesEntry*> *getOpenTablesJson = [[NSMutableArray alloc] init];
    
    if (self.openTablesEntries == nil || self.openTablesEntries.count <= 0) {
        return getOpenTablesJson;
    }
    
    for (SPIOpenTablesEntry *response in self.openTablesEntries) {
        [getOpenTablesJson addObjectsFromArray:[NSArray arrayWithObject:response.toJsonObject]];
    }
    
    return getOpenTablesJson;
}

- (SPIMessage *)toMessage:(NSString *)messageId {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[self getOpenTables] forKey:@"tables"];
    
    return [[SPIMessage alloc] initWithMessageId:messageId eventName:SPIPayAtTableOpenTablesKey data:data needsEncryption:true];
}

@end
