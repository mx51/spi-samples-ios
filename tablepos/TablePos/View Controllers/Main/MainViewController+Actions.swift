//
//  MainViewController+Actions.swift
//  TablePos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    
    @IBAction func btnOpenTableClicked(_ sender: Any) {        
        let tableIdInt:Int? = Int(txtTableId.text!)
        if tableIdInt == nil || tableIdInt! <= 0 {
            showMessage(title: "Open Table", msg: "Incorrect Table Id!", type: "ERROR", isShow: true)
            return
        }
        
        let tableId = txtTableId.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if TableApp.current.tableToBillMapping[tableId!] != nil {
            let bill: Bill = TableApp.current.billsStore[TableApp.current.tableToBillMapping[tableId!]!]!
            showMessage(title: "Open Table", msg: "Table Already Open: \(bill.toString())", type: "WARNING", isShow: true)
            return
        }
        
        let newBill = Bill()
        newBill.billId = newBillId()
        newBill.tableId = tableId!
        newBill.operatorId = txtOperatorId.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        newBill.label = txtLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        newBill.locked = swchLockedTable.isOn
        
        TableApp.current.billsStore[newBill.billId!] = newBill
        TableApp.current.tableToBillMapping[newBill.tableId!] = newBill.billId
        
        showMessage(title: "Open Table", msg: "Opened: \(newBill.toString())", type: "INFO", isShow: true)
    }
    
    @IBAction func btnAddTableClicked(_ sender: Any) {
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        
        let tableId = txtTableId.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if TableApp.current.tableToBillMapping[tableId!] == nil {
            showMessage(title: "Add Table", msg: "Table not Open.", type: "WARNING", isShow: true)
            return
        }
        
        let bill: Bill = TableApp.current.billsStore[TableApp.current.tableToBillMapping[tableId!]!]!
        if bill.locked! {
            showMessage(title: "Add Table", msg: "Table is Locked.", type: "WARNING", isShow: true)
            return
        }
        
        bill.totalAmount! += amount
        bill.outstandingAmount! += amount
        
        showMessage(title: "Add Table", msg: "Updated: \(bill.toString())", type: "INFO", isShow: true)
    }
    
    @IBAction func btnLockUnlockTableClicked(_ sender: Any) {
        let tableId = txtTableId.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tableIdInt:Int? = Int(tableId!)
        if tableIdInt == nil || tableIdInt! <= 0 {
            showMessage(title: "Lock/UnLock Table", msg: "Incorrect Table Id!", type: "ERROR", isShow: true)
            return
        }
        
        if (TableApp.current.tableToBillMapping[tableId!] == nil) {
            showMessage(title: "Lock/UnLock Table", msg: "Table not Open.", type: "WARNING", isShow: true)
            return
        }
        
        let bill: Bill = TableApp.current.billsStore[TableApp.current.tableToBillMapping[tableId!]!]!
        bill.locked = swchLockedTable.isOn
        
        let msg: String = bill.locked! ? "Locked" : "UnLocked"
        showMessage(title: "Lock/UnLock Table", msg: "Table is \(msg): \(bill.toString())", type: "INFO", isShow: true)
    }
    
    @IBAction func btnCloseTableClicked(_ sender: Any) {
        let tableId = txtTableId.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if TableApp.current.tableToBillMapping[tableId!] == nil {
            showMessage(title: "Close Table", msg: "Table not Open.", type: "WARNING", isShow: true)
            return
        }
        
        let bill: Bill = TableApp.current.billsStore[TableApp.current.tableToBillMapping[tableId!]!]!
        if bill.locked! {
            showMessage(title: "Close Table", msg: "Table is Locked.", type: "WARNING", isShow: true)
            return
        }
        
        if (bill.outstandingAmount)! > 0 {
            showMessage(title: "Close Table", msg: "Bill not Paid Yet: \(bill.toString())", type: "WARNING", isShow: true)
            return
        }
        
        TableApp.current.tableToBillMapping.removeValue(forKey: tableId!)
        TableApp.current.assemblyBillDataStore.removeValue(forKey: (bill.billId)!)
        showMessage(title: "Close Table", msg: "Closed: \(bill.toString())", type: "INFO", isShow: true)
    }
    
    @IBAction func btnListTablesClicked(_ sender: Any) {
        var listTables: String = "\n"
        if TableApp.current.tableToBillMapping.count > 0 {
            var openTables: String = ""
            for key in TableApp.current.tableToBillMapping.keys {
                if openTables != "" {
                    openTables += ",\n"
                }
                
                openTables += key
            }
            
            listTables = "#    Open Tables:\n\(openTables)\n"
        } else {
            showMessage(title: "List Tables", msg: "# No Open Tables.", type: "INFO", isShow: true)
        }
        
        if TableApp.current.billsStore.count > 0 {
            var openBills: String = ""
            for key in TableApp.current.billsStore.keys {
                if openBills != "" {
                    openBills += ",\n"
                }
                
                openBills += key
            }
            
            listTables += "# My Bills Store:\n\(openBills)\n"
        }
        
        if TableApp.current.assemblyBillDataStore.count > 0 {
            var openAssemblyBills: String = ""
            for key in TableApp.current.assemblyBillDataStore.keys {
                if openAssemblyBills != "" {
                    openAssemblyBills += ",\n"
                }
                
                openAssemblyBills += key
            }
            
            listTables = "# Assembly Bills Data:\n\(openAssemblyBills)"
        }
        
        showMessage(title: "List Tables", msg: "\(listTables)", type: "INFO", isShow: true)
    }
    
    @IBAction func btnPrintTableClicked(_ sender: Any) {
        let tableId = txtTableId.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if (TableApp.current.tableToBillMapping[tableId!] == nil) {
            showMessage(title: "Print Table", msg: "Table not Open.", type: "WARNING", isShow: true)
            return
        }
        
        printBill(billId: TableApp.current.tableToBillMapping[tableId!]! , title: "Print Table")
    }
    
    @IBAction func btnPrintBillClicked(_ sender: Any) {
        printBill(billId: txtBillId.text!, title: "Print Bill")
    }
    
    @IBAction func btnRecoverClicked(_ sender: UIButton) {
        guard let referenceId = txtReferenceId.text else { return }
        TableApp.current.client.initiateRecovery(referenceId, transactionType: .getLastTransaction, completion: printResult)
    }
    
    @IBAction func btnPurchaseClicked(_ sender: Any) {
        let posRefId = "purchase-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        client.initiatePurchaseTx(posRefId,
                                  purchaseAmount: amount,
                                  tipAmount: 0,
                                  cashoutAmount: 0,
                                  promptForCashout: false,
                                  options:options,
                                  completion: printResult)
    }
    
    @IBAction func btnRefundClicked(_ sender: Any) {
        let posRefId = "yuck-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        let suppressMerchantPassword =  TableApp.current.settings.suppressMerchantPassword ?? false
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        client.initiateRefundTx(posRefId,
                                amountCents: amount,
                                suppressMerchantPassword: suppressMerchantPassword,
                                options: options,
                                completion: printResult)
    }
    
    @IBAction func btnSettleClicked(_ sender: Any) {
        let id = SPIRequestIdHelper.id(for: "settle")
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        client.initiateSettleTx(id,
                                options: options,
                                completion: printResult)
    }
    
    func newBillId() -> String {
        let orginalDate = Date()
        return String(orginalDate.timeIntervalSince1970)
    }
    
    func printBill(billId: String, title: String) {
        let billId = billId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if TableApp.current.billsStore[billId] == nil {
            showMessage(title: title, msg: "Bill Not Found.", type: "ERROR", isShow: true)
            return
        }
        
        let bill: Bill = TableApp.current.billsStore[billId]! 
        showMessage(title: title, msg: "Bill: \(bill.toString())", type: "INFO", isShow: true)
    }
    
    func sanitizePrintText(_ text: String?) -> String? {
        var sanitizeText: String? = text?.replacingOccurrences(of: "\\r\\n", with: "\n");
        sanitizeText = sanitizeText?.replacingOccurrences(of: "\\n", with: "\n");
        sanitizeText = sanitizeText?.replacingOccurrences(of: "\\\\emphasis", with: "\\emphasis");
        return sanitizeText?.replacingOccurrences(of: "\\\\clear", with: "\\clear");
    }
    
    func showMessage(title: String, msg: String, type: String, isShow: Bool, completion: (() -> Swift.Void)? = nil) {
        logMessage("\(type): \(msg)")
        
        if isShow {
            showAlert(title: title, message: msg)
        }
    }
    
    func setReceiptHeaderFooter() -> SPITransactionOptions {
        let settings = TableApp.current.settings
        let options = SPITransactionOptions()
        
        if let receiptHeader = settings.receiptHeader, receiptHeader.count > 0 {
            options.customerReceiptHeader = sanitizePrintText(receiptHeader)
            options.merchantReceiptHeader = sanitizePrintText(receiptHeader)
        }
        if let receiptFooter = settings.receiptFooter, receiptFooter.count > 0 {
            options.customerReceiptFooter = sanitizePrintText(receiptFooter)
            options.merchantReceiptFooter = sanitizePrintText(receiptFooter)
        }
        
        return options
    }
}
