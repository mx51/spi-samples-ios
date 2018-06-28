//
//  MainViewController+Actions.swift
//  KebabPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    
    @IBAction func btnPurchaseClicked(_ sender: Any) {
        let posRefId = "kebab-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")

        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        var tipAmount = 0
        var cashout = 0

        if segmentExtraAmount.selectedSegmentIndex > 0, let extraAmount = Int(txtExtraAmount.text ?? "") {
            if (segmentExtraAmount.selectedSegmentIndex == 1) {
                // Extra option is tip
                tipAmount = extraAmount
            } else if (segmentExtraAmount.selectedSegmentIndex == 2) {
                // Extra option is cashout
                cashout = extraAmount
            }
        }
        let promptCashout = false

        client.enablePayAtTable()
        client.initiatePurchaseTx(posRefId, purchaseAmount: amount, tipAmount: tipAmount, cashoutAmount: cashout, promptForCashout: promptCashout, completion: printResult)
    }
    
    @IBAction func btnMotoClicked(_ sender: Any) {
        let posRefId = "kebab-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        client.initiateMotoPurchaseTx(posRefId, amountCents: amount, completion: printResult)
    }
    
    @IBAction func btnRefundClicked(_ sender: Any) {
        let posRefId = "yuck-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")

        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        client.initiateRefundTx(posRefId, amountCents: amount, completion: printResult)
    }
    
    @IBAction func btnCashOutClicked(_ sender: Any) {
        let posRefId = "launder-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")

        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        client.initiateCashoutOnlyTx(posRefId, amountCents: amount, completion: printResult)
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
        KebabApp.current.client.initiateRecovery(referenceId, transactionType: .getLastTransaction, completion: printResult)
    }
    
}
