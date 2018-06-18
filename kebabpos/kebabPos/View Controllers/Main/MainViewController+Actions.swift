//
//  MainViewController+Actions.swift
//  kebabPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    @IBAction func btnPurchaseClicked(_ sender: Any) {
        let posRefId = "kebab-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")

        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { //Amount Cents
            return
        }
        var tipAmount = 0
        var cashout = 0

        if segmentExtraAmount.selectedSegmentIndex > 0, let extraAmount = Int(txtExtraAmount.text ?? "") {
            //Extra option is tip
            if (segmentExtraAmount.selectedSegmentIndex == 1) {
                tipAmount = extraAmount
            //Extra option is cashout
            } else if (segmentExtraAmount.selectedSegmentIndex == 2) {
                cashout = extraAmount
            }

        }
        let promptCashout = false

        client.enablePayAtTable()
        client.initiatePurchaseTxV2(posRefId, purchaseAmount: amount, tipAmount: tipAmount, cashoutAmount: cashout, promptForCashout: promptCashout, completion: printResult)
    }
    @IBAction func btnRefundClicked(_ sender: Any) {
        let posRefId = "yuck-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")

        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { //Amount Cents
            return
        }
        client.initiateRefundTx(posRefId, amountCents: amount, completion: printResult)
    }
    @IBAction func btnCashOutClicked(_ sender: Any) {
        let posRefId = "launder-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")

        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { //Amount Cents
            return
        }
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
        guard let referenceId = txtReferenceId.text else {
            return
        }
        KebabApp.current.client.initiateRecovery(referenceId, transactionType: .getLastTransaction, completion: printResult)
    }
}
