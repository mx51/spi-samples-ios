//
//  File.swift
//  TablePos
//
//  Created by Metin Avci on 15/8/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension TableApp: SPIPayAtTableDelegate {    
    func pay(atTableGetBillStatus billId: String!, tableId: String!, operatorId: String!, paymentFlowStarted: Bool) -> SPIBillStatusResponse! {
        let response: SPIBillStatusResponse = SPIBillStatusResponse()
        var billId = billId
        
        if billId == nil  {
            if (tableToBillMapping[tableId] == nil) {
                response.result = SPIBillRetrievalResult.BillRetrievalResultInvalidTableId
                return response
            }
            
            billId = tableToBillMapping[tableId]
        }
        
        if billsStore[billId!] == nil {
            response.result = SPIBillRetrievalResult.BillRetrievalResultInvalidBillId
            return response
        }
        
        if  ((billsStore[billId!]?.locked)! && paymentFlowStarted) {            
            response.result = SPIBillRetrievalResult.BillRetrievalResultInvalidTableId
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.payAtTableGetBillStatus.rawValue), object: MessageInfo(title: "Get Bill Status", type: "INFO", message: "Table \(tableId ?? "") is Locked!", isShow: true))
            return response
        }
        
        let myBill = billsStore[billId!]
        myBill?.locked = paymentFlowStarted
        
        response.result = SPIBillRetrievalResult.BillRetrievalResultSuccess
        response.billId = billId
        response.tableId = tableId
        response.operatorId = operatorId
        response.totalAmount = (myBill?.totalAmount)!
        response.outstandingAmount = (myBill?.outstandingAmount)!
        response.billData = mx51BillDataStore[billId!]
        return response
    }
    
    func pay(atTableBillPaymentReceived billPayment: SPIBillPayment!, updatedBillData: String!) -> SPIBillStatusResponse! {
        let response: SPIBillStatusResponse = SPIBillStatusResponse()
        
        if billsStore[billPayment.billId!] == nil {
            response.result = SPIBillRetrievalResult.BillRetrievalResultInvalidBillId
            return response
        }
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.payAtTableGetBillStatus.rawValue), object: MessageInfo(title: "Bill Payment Received", type: "INFO", message: "# Got a \(billPayment!.paymentType) Payment against bill \(String(describing: billPayment!.billId)) for table \(String(describing: billPayment!.tableId))", isShow: true))
        
        let bill: Bill = billsStore[billPayment.billId]!
        bill.outstandingAmount! -= billPayment.purchaseAmount
        bill.tippedAmount! += billPayment.tipAmount
        bill.surchargeAmount! += billPayment.surchargeAmount
        bill.locked = bill.outstandingAmount == 0 ? false: true
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.payAtTableGetBillStatus.rawValue), object: MessageInfo(title: "Bill Payment Received", type: "INFO", message: "Updated Bill: \(bill.toString())", isShow: true))
        
        mx51BillDataStore[billPayment.billId] = updatedBillData
        
        response.result = SPIBillRetrievalResult.BillRetrievalResultSuccess
        response.outstandingAmount = bill.outstandingAmount!
        response.totalAmount = bill.totalAmount!
        
        return response
    }
    
    func pay(atTableGetOpenTables operatorId: String!) -> SPIGetOpenTablesResponse! {
        let response: SPIGetOpenTablesResponse = SPIGetOpenTablesResponse()
        let openTablesArray = NSMutableArray()
        var openTables: String = ""
        var isOpenTables = false
        
        if tableToBillMapping.count > 0 {
            for item in tableToBillMapping {
                if billsStore[item.value]!.operatorId == operatorId  && billsStore[item.value]!.outstandingAmount! > 0 &&
                    !billsStore[item.value]!.locked!{
                    if !isOpenTables {
                        openTables = "Open Tables:\n"
                        isOpenTables = true
                    }
                    
                    let openTablesItem = SPIOpenTablesEntry()
                    openTablesItem.tableId = item.key
                    openTablesItem.label = billsStore[item.value]!.label!
                    openTablesItem.outstandingAmount = (billsStore[item.value]?.outstandingAmount)!
                    openTables += "Table ID: \(openTablesItem.tableId.description) Label: \(openTablesItem.label.description) Outstanding Amount: \(Double(openTablesItem.outstandingAmount) / 100.00)\n"
                    openTablesArray.add(openTablesItem)
                }
            }
        }
        
        if !isOpenTables {
            //No Open Tables.
        } else {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.payAtTableGetBillStatus.rawValue), object: MessageInfo(title: "Bill Payment Received", type: "INFO", message: openTables, isShow: true))
        }
        
        response.openTablesEntries = openTablesArray
        return response
    }
    
    func pay(atTableBillPaymentFlowEnded message: SPIMessage!) {
        let billPaymentFlowEndedResponse: SPIBillPaymentFlowEndedResponse = SPIBillPaymentFlowEndedResponse(message: message)
        var message: String = ""
        
        if !(billsStore[billPaymentFlowEndedResponse.tableId] != nil) {
            //Table Id not found
            return
        }
        
        let myBill = billsStore[billPaymentFlowEndedResponse.billId!]
        myBill!.locked = false
        
        message += "Bill Id: \(billPaymentFlowEndedResponse.billId.description)\n"
        message += "Table Id: \(billPaymentFlowEndedResponse.tableId.description)\n"
        message += "Operator Id: \(billPaymentFlowEndedResponse.operatorId.description)\n"
        message += "Bill OutStanding Amount: $\(Double(billPaymentFlowEndedResponse.billOutstandingAmount) / 100.00)\n"
        message += "Bill Total Amount: $\(Double(billPaymentFlowEndedResponse.billTotalAmount) / 100.00)\n"
        message += "Card Total Count: \(billPaymentFlowEndedResponse.cardTotalCount)\n"
        message += "Card Total Amount: $\(Double(billPaymentFlowEndedResponse.cardTotalAmount) / 100.00)\n"
        message += "Cash Total Count: \(billPaymentFlowEndedResponse.cashTotalCount)\n"
        message += "Cash Total Amount: $\(Double(billPaymentFlowEndedResponse.cashTotalAmount) / 100.00)\n"
        message += "Locked: \(myBill!.locked!.description)"
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.payAtTableGetBillStatus.rawValue), object: MessageInfo(title: "Bill Payment Flow Ended", type: "INFO", message: message, isShow: true))
    }    
}
