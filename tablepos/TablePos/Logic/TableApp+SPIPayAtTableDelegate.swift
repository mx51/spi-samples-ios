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
    func pay(atTableGetBillStatus billId: String!, tableId: String!, operatorId: String!) -> SPIBillStatusResponse! {
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
        
        let myBill = billsStore[billId!]
        
        response.result = SPIBillRetrievalResult.BillRetrievalResultSuccess
        response.billId = billId
        response.tableId = tableId
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
        
        SPILogMsg("# Got a \(billPayment!.paymentType) Payment against bill \(String(describing: billPayment!.billId)) for table \(String(describing: billPayment!.tableId))")
        
        let bill: Bill = billsStore[billPayment.billId]!
        bill.outstandingAmount! -= billPayment.purchaseAmount
        bill.tippedAmount! += billPayment.tipAmount
        
        SPILogMsg("Updated Bill: \(bill.toString())")
        
        assemblyBillDataStore[billPayment.billId] = updatedBillData
        
        response.result = SPIBillRetrievalResult.BillRetrievalResultSuccess
        response.outstandingAmount = bill.outstandingAmount!
        response.totalAmount = bill.totalAmount!
        
        return response
    }
    
}
