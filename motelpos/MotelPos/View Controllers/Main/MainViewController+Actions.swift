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
        let posRefId = "propen-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }        
        spiPreauth.initiateOpenTx(posRefId, amountCents: amount, completion: printResult)
    }
    
    @IBAction func btnTopupClicked(_ sender: Any) {
        let posRefId = "prtopup-" + txtPreauthId.text! + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        spiPreauth.initiateTopupTx(posRefId, preauthId: txtPreauthId.text, amountCents: amount, completion: printResult)
    }
    
    @IBAction func btnPartialCancelClicked(_ sender: Any) {
        let posRefId = "prpartialcancel-" + txtPreauthId.text! + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        spiPreauth.initiatePartialCancellationTx(posRefId, preauthId: txtPreauthId.text, amountCents: amount, completion:printResult)
    }
    
    @IBAction func btnExtendClicked(_ sender: Any) {
        let posRefId = "prextend-" + txtPreauthId.text! + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        spiPreauth.initiateExtendTx(posRefId, preauthId: txtPreauthId.text, completion: printResult)
    }
    
    @IBAction func btnCancelClicked(_ sender: Any) {
        let posRefId = "prcancel-" + txtPreauthId.text! + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        spiPreauth.initiateCancelTx(posRefId, preauthId: txtPreauthId.text, completion: printResult)
    }
    
    @IBAction func btnCompleteClicked(_ sender: Any) {
        let posRefId = "prcomplete-" + txtPreauthId.text! + "-" + Date().toString(format: "dd-MM-yyyy-HH-mm-ss")
        
        guard let amount = Int(txtTransactionAmount.text ?? ""), amount > 0 else { return }
        spiPreauth.initiateCompletionTx(posRefId, preauthId: txtPreauthId.text, amountCents: amount, completion: printResult)
    }
    
    @IBAction func btnRecoverClicked(_ sender: UIButton) {
        guard let referenceId = txtReferenceId.text else { return }
        MotelApp.current.client.initiateRecovery(referenceId, transactionType: .getLastTransaction, completion: printResult)
    }
    
}
