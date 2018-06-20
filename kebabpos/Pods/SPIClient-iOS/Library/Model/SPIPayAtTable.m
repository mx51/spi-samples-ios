//
//  SPIPayAtTable.m
//  SPIClient-iOS
//
//  Created by Amir Kamali on 20/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

#import "SPIPayAtTable.h"
#import "NSString+Util.h"
#import "SPILogger.h"
#import "SPIClient.h"
@implementation SPIBillStatusResponse
- (NSArray<SPIPaymentHistoryEntry *> *)getBillPaymentHistory{
    if (_billData == nil || [_billData isEqualToString:@""]){
        return [[NSArray alloc] init];
    }
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:_billData options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    NSLog(@"%@", decodedString); // foo
   
    NSError *jsonError = nil;
    NSData  *jsonData  = [NSJSONSerialization dataWithJSONObject:decodedString options:0 error:&jsonError];

    
    if (jsonError) {
        //ERROR
        NSLog(@"jsonError: %@", jsonError);
        return [[NSArray alloc] init];
    }
    NSMutableArray * paymentHistory = [[NSMutableArray alloc] init];
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
    for (NSDictionary * historyValue in jsonObject.allValues.firstObject){
        SPIPaymentHistoryEntry *historyItem = [[SPIPaymentHistoryEntry alloc] initWithDictionary:historyValue];
        [paymentHistory addObject:historyItem];
    }
    return [paymentHistory copy];
}
+ (NSString *)toBillData:(NSArray<SPIPaymentHistoryEntry *> *)ph{
    if (ph.count < 1){
        return @"";
    }
    
    NSError *writeError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:ph options:NSJSONWritingPrettyPrinted error:&writeError];
    NSString *bphStr = [jsonData base64EncodedStringWithOptions:0];
    return bphStr;
}

- (SPIMessage *)toMessage:(NSString *)messageId{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[NSNumber numberWithInteger:BillRetrievalResultSuccess] forKey:@"success"];
    if (_billId.length > 0) {
        [data setObject:_billId forKey:@"bill_id"];
    }
    if (_tableId.length > 0) {
        [data setObject:_tableId forKey:@"table_id"];
    }
    if (_result == BillRetrievalResultSuccess){
        [data setObject:@"bill_total_amount" forKey:[NSNumber numberWithInteger:_totalAmount]];
        [data setObject:@"bill_outstanding_amount" forKey:[NSNumber numberWithInteger:_outstandingAmount]];
        [data setObject:@"bill_payment_history" forKey:[self getBillPaymentHistory]];
    }else{
        [data setObject:@"error_reason" forKey:[NSNumber numberWithInt:_result].stringValue];
        [data setObject:@"error_detail" forKey:[NSNumber numberWithInt:_result].stringValue];
    }
    SPIMessage *message = [[SPIMessage alloc] initWithMessageId:messageId eventName:SPIPayAtTableBillDetailsKey data:data needsEncryption:true];
    return  message;
}

@end

@implementation SPIPaymentHistoryEntry

- (instancetype)initWithDictionary:(NSDictionary *)data{
    _paymentType = [data valueForKey:@"payment_type"];
    _paymentSummary = [data valueForKey:@"payment_summary"];
    return self;
}

- (NSString *)getTerminalRefId{
    if ([_paymentSummary.allKeys containsObject:@"terminal_ref_id"]){
        return _paymentSummary[@"terminal_ref_id"];
    }
    return nil;
}

- (NSDictionary *)toJsonObject{
    NSMutableDictionary * data = [[NSMutableDictionary alloc] init];
    [data setObject:_paymentType forKey:@"payment_type"];
    [data setObject:_paymentSummary forKey:@"payment_summary"];
    return data;
}

@end

@interface SPIBillPayment()

   @property (nonatomic,retain) SPIMessage* incomingAdvice;

@end

@implementation SPIBillPayment

- (instancetype)initWithMessage:(SPIMessage *)message{
    _incomingAdvice = message;
    _billId = [_incomingAdvice getDataStringValue:@"bill_id"];
    _tableId = [_incomingAdvice getDataStringValue:@"table_id"];
    _operatorId = [_incomingAdvice getDataStringValue:@"operator_id"];
  
    
    NSString *paymentType = [_incomingAdvice getDataStringValue:@"payment_type"];
    if ([paymentType isEqualToString:[SPIBillPayment paymentTypeString:SPIPaymentTypeCard]]){
        _paymentType = SPIPaymentTypeCard;
    }else if ([paymentType isEqualToString:[SPIBillPayment paymentTypeString:SPIPaymentTypeCash]])
    {
        _paymentType = SPIPaymentTypeCash;
    }
    NSDictionary<NSString *,NSObject *> *data = (NSDictionary *)[message.data valueForKey:@"payment_details"];
    
    // this is when we ply the sub object "payment_details" into a purchase response for convenience.
    SPIMessage *purchaseMsg = [[SPIMessage alloc] initWithMessageId:message.mid eventName:@"payment_details" data:data needsEncryption:false];
    
    _purchaseResponse = [[SPIPurchaseResponse alloc] initWithMessage:purchaseMsg];
    
    _purchaseAmount = [_purchaseResponse getPurchaseAmount];
    
    _TipAmount =  [_purchaseResponse getTipAmount];
    return self;
}

+ (NSString *)paymentTypeString:(SPIPaymentType)ptype{
    if (ptype == SPIPaymentTypeCard){
        return @"CARD";
    }
    else if (ptype == SPIPaymentTypeCash){
        return @"CASH";
    }
    return nil;
}

@end

@implementation SPIPayAtTableConfig

- (SPIMessage *)toMessage:(NSString *)messageId{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:@true forKey:@"pay_at_table_enabled"];
    [data setValue:[NSNumber numberWithBool:_operatorIdEnabled] forKey:@"operator_id_enabled"];
    [data setValue:[NSNumber numberWithBool:_splitByAmountEnabled] forKey:@"split_by_amount_enabled"];
    [data setValue:[NSNumber numberWithBool:_equalSplitEnabled] forKey:@"equal_split_enabled"];
    [data setValue:[NSNumber numberWithBool:_tippingEnabled] forKey:@"tipping_enabled"];
    [data setValue:[NSNumber numberWithBool:_summaryReportEnabled] forKey:@"summary_report_enabled"];
    [data setValue:[NSNumber numberWithBool:_labelPayButton] forKey:@"pay_button_label"];
    [data setValue:[NSNumber numberWithBool:_labelOperatorId] forKey:@"operator_id_label"];
    [data setValue:[NSNumber numberWithBool:_labelTableId] forKey:@"table_id_label"];
    [data setValue:_allowedOperatorIds forKey:@"operator_id_list"];
    SPIMessage *message = [[SPIMessage alloc] initWithMessageId:messageId eventName:SPIPayAtTableSetTableConfigKey data:data needsEncryption:true];
    return message;
}

+ (SPIMessage *)featureDisableMessage:(NSString *)messageId{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:@false forKey:@"pay_at_table_enabled"];
    
    SPIMessage *message = [[SPIMessage alloc] initWithMessageId:messageId eventName:SPIPayAtTableSetTableConfigKey data:data needsEncryption:true];
    return message;
}

@end

@class SPIClient;
@interface SPIPayAtTable(){
    SPIClient * _spi;
}
@end

@implementation SPIPayAtTable

- (instancetype)initWithClient:(SPIClient *)spi{
    _spi = spi;
    return self;
}

- (void)PushPayAtTableConfig{
    
}

- (void)handleGetBillDetailsRequest:(SPIMessage *)message{
    NSString * operatorId = [message getDataStringValue:@"operator_id"];
    NSString * tableId = [message getDataStringValue:@"table_id"];
    
    // Ask POS for Bill Details for this tableId, inluding encoded PaymentData
    SPIBillStatusResponse *billStatus = [_delegate payAtTableGetBillStatus:nil tableId:tableId operatorId:operatorId];
    billStatus.tableId = tableId;
    if (billStatus.totalAmount <= 0){
        SPILog(@"Table has 0 total amount. not sending it to eftpos.");
        billStatus.result = BillRetrievalResultInvalidTableId;
    }
    [_spi send:[billStatus toMessage:message.mid]];
}

- (void)handleBillPaymentAdvice:(SPIMessage *)message{
    SPIBillPayment *billPayment = [[SPIBillPayment alloc] initWithMessage:message];
    
    // Ask POS for Bill Details, inluding encoded PaymentData
    SPIBillStatusResponse *existingBillStatus = [_delegate payAtTableGetBillStatus:billPayment.billId tableId:billPayment.tableId operatorId:billPayment.operatorId];
    if (existingBillStatus.result != BillRetrievalResultSuccess){
        SPILog(@"Could not retrieve Bill Status for Payment Advice. Sending Error to Eftpos.");
        [_spi send:[existingBillStatus toMessage:message.mid]];
    }
    NSArray *existingHistory = existingBillStatus.getBillPaymentHistory;
    for (SPIPaymentHistoryEntry *response in existingHistory) {
        if ([response.getTerminalRefId isEqualToString:billPayment.purchaseResponse.getTerminalReferenceId]){
            // We have already processed this payment.
            // perhaps Eftpos did get our acknowledgement.
            // Let's update Eftpos.
            SPILog(@"Had already received this bill_paymemnt advice from eftpos. Ignoring.");
            [_spi send:[existingBillStatus toMessage:message.mid]];
            return;
        }
    }
    // Let's add the new entry to the history
    NSMutableArray<SPIPaymentHistoryEntry*> *updatedHistoryEntries = [[NSMutableArray alloc] initWithArray:existingHistory];
    SPIPaymentHistoryEntry *newPaymentEntry = [[SPIPaymentHistoryEntry alloc] init];
    newPaymentEntry.paymentType = [SPIBillPayment paymentTypeString:billPayment.paymentType];
    newPaymentEntry.paymentSummary = [billPayment.purchaseResponse toPaymentSummary];
    [updatedHistoryEntries addObject:newPaymentEntry];
    
    NSString *updatedBillData = [SPIBillStatusResponse toBillData:[updatedHistoryEntries copy]];
    
    // Advise POS of new payment against this bill, and the updated BillData to Save.
    SPIBillStatusResponse *updatedBillStatus = [_delegate PayAtTableBillPaymentReceived:billPayment updatedBillData:updatedBillData];
    
    // Just in case client forgot to set these:
    updatedBillStatus.billId = billPayment.billId;
    updatedBillStatus.tableId = billPayment.tableId;
    
    if (updatedBillStatus.result != BillRetrievalResultSuccess){
        SPILog(@"POS Errored when being Advised of Payment. Letting EFTPOS know, and sending existing bill data.");
        updatedBillStatus.billData = existingBillStatus.billData;
    }else{
        updatedBillStatus.billData = updatedBillData;
    }
    
    [_spi send:[updatedBillStatus toMessage:message.mid]];
}

- (void)handleGetTableConfig:(SPIMessage *)message{
    [_spi send:[_config toMessage:message.mid]];
}

@end

