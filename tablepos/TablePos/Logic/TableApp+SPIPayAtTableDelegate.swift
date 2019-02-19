//
//  File.swift
//  TablePos
//
//  Created by Metin Avci on 15/8/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
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
        
        if  (billsStore[billId!]?.locked)! {            
            response.result = SPIBillRetrievalResult.BillRetrievalResultInvalidTableId
            SPILogMsg("\(tableId ?? "") Table is Locked!")
            //mainViewController.showMessage(title: "GetBillStatus", msg: "\(tableId ?? "") Table is Locked!", type: "ERROR", isShow: true)
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
        response.billData = assemblyBillDataStore[billId!]
        return response
    }
    
    func pay(atTableBillPaymentReceived billPayment: SPIBillPayment!, updatedBillData: String!) -> SPIBillStatusResponse! {
        let response: SPIBillStatusResponse = SPIBillStatusResponse()
        
        if billsStore[billPayment.billId!] == nil {
            response.result = SPIBillRetrievalResult.BillRetrievalResultInvalidBillId
            return response
        }
        
        //MainViewController().showMessage(title: "BillPaymentReceived", msg:"# Got a \(billPayment!.paymentType) Payment against bill \(String(describing: billPayment!.billId)) for table \(String(describing: billPayment!.tableId))", type: "INFO", isShow: true)
        SPILogMsg("# Got a \(billPayment!.paymentType) Payment against bill \(String(describing: billPayment!.billId)) for table \(String(describing: billPayment!.tableId))")
        
        let bill: Bill = billsStore[billPayment.billId]!
        bill.outstandingAmount! -= billPayment.purchaseAmount
        bill.tippedAmount! += billPayment.tipAmount
        bill.locked = bill.outstandingAmount == 0 ? false: true
        
        SPILogMsg("Updated Bill: \(bill.toString())")
        
        assemblyBillDataStore[billPayment.billId] = updatedBillData
        
        response.result = SPIBillRetrievalResult.BillRetrievalResultSuccess
        response.outstandingAmount = bill.outstandingAmount!
        response.totalAmount = bill.totalAmount!
        
        return response
    }
    
    func pay(atTableGetOpenTables operatorId: String!) -> SPIGetOpenTablesResponse! {
        let response: SPIGetOpenTablesResponse = SPIGetOpenTablesResponse()
        let openTablesArray = NSMutableArray()
        
        SPILogMsg("Open Tables:")
        
        if tableToBillMapping.count > 0 {
            for item in tableToBillMapping {
                if billsStore[item.value]!.operatorId == operatorId {
                    let openTablesItem = SPIOpenTablesEntry()
                    openTablesItem.tableId = item.key
                    openTablesItem.label = billsStore[item.value]!.label!
                    openTablesItem.outstandingAmount = (billsStore[item.value]?.outstandingAmount)!
                    SPILogMsg("\(openTablesItem)")
                    openTablesArray.add(openTablesItem)
                }
            }
        } else {
            SPILogMsg("No Open Tables.")
        }
        
        response.openTablesData = openTablesArray
        return response
    }
    
    func pay(atTableBillPaymentFlowEnded message: SPIMessage!) {
        let billPaymentFlowEndedResponse: SPIBillPaymentFlowEndedResponse = SPIBillPaymentFlowEndedResponse(message: message)
        
        if !(billsStore[billPaymentFlowEndedResponse.billId] != nil) {
            SPILogMsg("Incorrect Bill Id!")
            return
        }
        
        let myBill = billsStore[billPaymentFlowEndedResponse.billId!]
        myBill?.locked = false
        
        SPILogMsg("Bill Id                : \(String(describing: billPaymentFlowEndedResponse.billId))")
        SPILogMsg("Table Id               : \(String(describing: billPaymentFlowEndedResponse.tableId))")
        SPILogMsg("Operator Id            : \(String(describing: billPaymentFlowEndedResponse.operatorId))")
        SPILogMsg("Bill OutStanding Amount: \(Double(billPaymentFlowEndedResponse.billOutstandingAmount) / 100.0)")
        SPILogMsg("Bill Total Amount      : \(Double(billPaymentFlowEndedResponse.billTotalAmount) / 100.0)")
        SPILogMsg("Card Total Count       : \(billPaymentFlowEndedResponse.cardTotalCount)")
        SPILogMsg("Card Total Amount      : \(billPaymentFlowEndedResponse.cardTotalAmount)")
        SPILogMsg("Cash Total Count       : \(billPaymentFlowEndedResponse.cashTotalCount)")
        SPILogMsg("Cash Total Amount      : \(billPaymentFlowEndedResponse.cashTotalAmount)")
        SPILogMsg("Locked                 : \(String(describing: myBill?.locked))")
    }
}
