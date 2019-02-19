//
//  MainViewController+Actions.swift
//  RamenPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    
    @IBAction func btnPurchaseClicked(_ sender: Any) {
        let posRefId = "ramen-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        var tipAmount = 0
        var cashout = 0
        var surchargeAmount = 0
        
        if segmentExtraAmount.selectedSegmentIndex > 0, let extraAmount = Int(txtExtraAmount.text ?? "") {
            if (segmentExtraAmount.selectedSegmentIndex == 1) {
                // Extra option is tip
                tipAmount = extraAmount
            } else if (segmentExtraAmount.selectedSegmentIndex == 2) {
                // Extra option is cashout
                cashout = extraAmount
            } else if (segmentExtraAmount.selectedSegmentIndex == 3) {
                // Extra option is surcharge
                surchargeAmount = extraAmount
            }
        }
        let promptCashout = false
        
        client.enablePayAtTable()
        
        let settings = RamenApp.current.settings
        
        // Receipt header/footer
        let options = SPITransactionOptions()
        if let receiptHeader = settings.receiptHeader, receiptHeader.count > 0 {
            options.customerReceiptHeader = receiptHeader
            options.merchantReceiptHeader = receiptHeader
        }
        if let receiptFooter = settings.receiptFooter, receiptFooter.count > 0 {
            options.customerReceiptFooter = receiptFooter
            options.merchantReceiptFooter = receiptFooter
        }
        
        client.initiatePurchaseTx(posRefId,
                                  purchaseAmount: amount,
                                  tipAmount: tipAmount,
                                  cashoutAmount: cashout,
                                  promptForCashout: promptCashout,
                                  options:options,
                                  surchargeAmount: surchargeAmount,
                                  completion: printResult)
    }
    
    @IBAction func btnMotoClicked(_ sender: Any) {
        let posRefId = "ramen-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        let isSuppressMerchantPassword =  RamenApp.current.settings.suppressMerchantPassword ?? false
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        var surchargeAmount = 0
        
        if segmentExtraAmount.selectedSegmentIndex > 0, let extraAmount = Int(txtExtraAmount.text ?? "") {
            if (segmentExtraAmount.selectedSegmentIndex == 3) {
                // Extra option is surcharge
                surchargeAmount = extraAmount
            }
        }
        
        client.initiateMotoPurchaseTx(posRefId, amountCents: amount, surchargeAmount: surchargeAmount, isSuppressMerchantPassword: isSuppressMerchantPassword, completion: printResult)
    }
    
    @IBAction func btnRefundClicked(_ sender: Any) {
        let posRefId = "yuck-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        let isSuppressMerchantPassword =  RamenApp.current.settings.suppressMerchantPassword ?? false
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        client.initiateRefundTx(posRefId, amountCents: amount, isSuppressMerchantPassword: isSuppressMerchantPassword, completion: printResult)
    }
    
    @IBAction func btnCashOutClicked(_ sender: Any) {
        let posRefId = "launder-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        var surchargeAmount = 0
        
        if segmentExtraAmount.selectedSegmentIndex > 0, let extraAmount = Int(txtExtraAmount.text ?? "") {
            if (segmentExtraAmount.selectedSegmentIndex == 3) {
                // Extra option is surcharge
                surchargeAmount = extraAmount
            }
        }
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        client.initiateCashoutOnlyTx(posRefId, amountCents: amount, surchargeAmount: surchargeAmount, completion: printResult)
    }
    
    @IBAction func btnSettleClicked(_ sender: Any) {
        let id = SPIRequestIdHelper.id(for: "settle")
        client.initiateSettleTx(id, completion: printResult)
    }
    
    @IBAction func btnSettleEnquiryClicked(_ sender: Any) {
        let id = SPIRequestIdHelper.id(for: "stlenq")
        client.initiateSettlementEnquiry(id, completion: printResult)
    }
    
    @IBAction func btnLastTransactionClicked(_ sender: Any) {
        client.initiateGetLastTx(completion: printResult)
    }
    
    @IBAction func btnRecoverClicked(_ sender: UIButton) {
        guard let referenceId = txtReferenceId.text else { return }
        RamenApp.current.client.initiateRecovery(referenceId, transactionType: .getLastTransaction, completion: printResult)
    }
    
    @IBAction func btnTerminalStatusRetrieveClicked(_ sender: UIButton) {
        client.getTerminalStatus()
    }
    
    @IBAction func btnTerminalConfigRetrieveClicked(_ sender: UIButton) {
        client.getTerminalConfiguration()
    }
    
    @IBAction func btnPrintClicked(_ sender: UIButton) {
        let settings = RamenApp.current.settings
        settings.posVendorKey = txtPosVendorKey.text
        settings.printText = sanitizePrintText(txtPrintText.text)
        
        if (client.state.status == SPIStatus.unpaired) {
            showMessage(title: "Print Receipt", msg: "Not idle", type: "ERROR", isShow: true)
            return
        }
        
        if let posVendorKey = settings.posVendorKey, posVendorKey.count > 0,
            let printText = settings.printText, printText.count > 0 {
            client.printReport(posVendorKey, payload: printText)
        } else {
            showMessage(title: "Print Receipt", msg: "Please fill the parameters", type: "INFO", isShow: true)
            return
        }        
    }
    
    func sanitizePrintText(_ text: String?) -> String? {
        let boldText: String? = text?.replacingOccurrences(of: "\\n", with: "\n");
        let newLineText: String? = boldText?.replacingOccurrences(of: "\\\\emphasis", with: "\\emphasis");
        return newLineText?.replacingOccurrences(of: "\\\\clear", with: "\\clear");
    }
    
    func showMessage(title: String, msg: String, type: String, isShow: Bool, completion: (() -> Swift.Void)? = nil) {
        logMessage("\(type): \(msg)")
        
        if isShow {
            showAlert(title: title, message: msg)
        }
    }
    
}
