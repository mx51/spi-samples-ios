//
//  MainViewController+Actions.swift
//  MotelPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    
    @IBAction func btnAccountVerifyClicked(_ sender: Any) {
        let posRefId = "actvfy-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        spiPreauth.initiateAccountVerifyTx(posRefId, completion: printResult)
    }
    
    @IBAction func btnOpenClicked(_ sender: Any) {
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else {
            showMessage(title: "Open", msg: "Amount is missing", type: "WARNING", isShow: true)
            return
        }
        
        let posRefId = "propen-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        spiPreauth.initiateOpenTx(posRefId,
                                  amountCents: amount,
                                  options: options,
                                  completion: printResult)
    }
    
    @IBAction func btnTopupClicked(_ sender: Any) {
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else {
            showMessage(title: "Pre-auth Top Up", msg: "Amount is missing", type: "WARNING", isShow: true)
            return
        }
        
        guard let preauthId = txtPreauthId.text, preauthId != "" else {
            showMessage(title: "Pre-auth Top Up", msg: "Pre-Auth ID is missing", type: "WARNING", isShow: true)
            return
        }
        
        let posRefId = "prtopup-" + preauthId + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        spiPreauth.initiateTopupTx(posRefId,
                                   preauthId: preauthId,
                                   amountCents: amount,
                                   options: options,
                                   completion: printResult)
    }
    
    @IBAction func btnPartialCancelClicked(_ sender: Any) {
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else {
            showMessage(title: "Pre-auth Partial Cancel", msg: "Amount is missing", type: "WARNING", isShow: true)
            return
        }
        
        guard let preauthId = txtPreauthId.text, preauthId != "" else {
            showMessage(title: "Pre-auth Partial Cancel", msg: "Pre-Auth ID is missing", type: "WARNING", isShow: true)
            return
        }
        
        let posRefId = "prpartialcancel-" + preauthId + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        spiPreauth.initiatePartialCancellationTx(posRefId,
                                                 preauthId: preauthId,
                                                 amountCents: amount,
                                                 options: options,
                                                 completion:printResult)
    }
    
    @IBAction func btnExtendClicked(_ sender: Any) {
        guard let preauthId = txtPreauthId.text, preauthId != "" else {
            showMessage(title: "Pre-auth Extend", msg: "Pre-Auth ID is missing", type: "WARNING", isShow: true)
            return
        }
        
        let posRefId = "prextend-" + preauthId + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        spiPreauth.initiateExtendTx(posRefId,
                                    preauthId: preauthId,
                                    options: options,
                                    completion: printResult)
    }
    
    @IBAction func btnCancelClicked(_ sender: Any) {
        guard let preauthId = txtPreauthId.text, preauthId != "" else {
            showMessage(title: "Pre-auth Cancel", msg: "Pre-Auth ID is missing", type: "WARNING", isShow: true)
            return
        }
        
        let posRefId = "prcancel-" + preauthId + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        spiPreauth.initiateCancelTx(posRefId,
                                    preauthId: preauthId,
                                    options: options,
                                    completion: printResult)
    }
    
    @IBAction func btnCompleteClicked(_ sender: Any) {
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else {
            showMessage(title: "Pre-auth Complete", msg: "Amount is missing", type: "WARNING", isShow: true)
            return
        }
        
        guard let preauthId = txtPreauthId.text, preauthId != "" else {
            showMessage(title: "Pre-auth Complete", msg: "Pre-Auth ID is missing", type: "WARNING", isShow: true)
            return
        }
        
        let surchargeAmount = Int(txtSurchargeAmount.text ?? "")
        
        let posRefId = "prcomplete-" + preauthId + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        // Receipt header/footer
        let options = setReceiptHeaderFooter()
        
        spiPreauth.initiateCompletionTx(posRefId,
                                        preauthId: preauthId,
                                        amountCents: amount,
                                        surchargeAmount: surchargeAmount ?? 0,
                                        options: options,
                                        completion: printResult)
    }
    
    @IBAction func btnRecoverClicked(_ sender: UIButton) {
        guard let referenceId = txtReferenceId.text, referenceId != "" else {
            showMessage(title: "Recovery", msg: "Reference ID is missing", type: "WARNING", isShow: true)
            return
        }
        
        MotelApp.current.client.initiateRecovery(referenceId, transactionType: .getLastTransaction, completion: printResult)
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
    
    func setReceiptHeaderFooter() -> SPITransactionOptions {
        let settings = MotelApp.current.settings
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
