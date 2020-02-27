//
//  MainViewController+TransactionFlowChange.swift
//  RamenPos
//
//  Created by Amir Kamali on 3/6/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    
    func stateChanged(state: SPIState? = nil) {
        guard let state = state ?? RamenApp.current.client.state else { return }
        
        updateUIFlowInfo(state: state)
        printFlowInfo(state: state)
        selectActions(state: state)
    }
    
    func updateUIFlowInfo(state: SPIState) {
        lblStatus.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        lblStatus.textColor = UIColor.darkGray
        
        btnConnection.title = "Pair"
        switch state.status {
        case .pairedConnected:
            lblStatus.text = "Connected"
            lblStatus.font = UIFont.systemFont(ofSize: 14, weight: UIFont.Weight.semibold)
            lblStatus.textColor = UIColor(red: 23.0/256, green: 156.0/255, blue: 63.0/255, alpha: 1.0)
            btnConnection.title = "Connection"
        case .pairedConnecting:
            lblStatus.text = "Connecting"
            break
        case .unpaired:
            lblStatus.text = "Not Connected"
            break
        default:
            break
        }
        
        lblPosId.text = RamenApp.current.settings.posId
        lblPosAddress.text = RamenApp.current.settings.eftposAddress
        lblFlowStatus.text = state.flow.name
        self.title = lblStatus.text
    }
    
    func selectActions(state: SPIState) {
        switch state.flow {
        case .idle:
            clear()
        case .pairing:
            if (state.pairingFlowState.isAwaitingCheckFromPos) {
                client.pairingConfirmCode()
            } else if (!state.pairingFlowState.isFinished) {
                pairCancel()
            } else if (state.pairingFlowState.isFinished) {
                ok()
            }
        case .transaction:
            if (state.txFlowState.isAwaitingSignatureCheck) {
                txSignature()
            } else if (state.txFlowState.isAwaitingPhoneForAuth) {
                txAuthCode()
            } else if (!state.txFlowState.isFinished && !state.txFlowState.isAttemptingToCancel) {
                txCancel()
            } else if (state.txFlowState.isFinished) {
                ok()
            }
        default:
            break
        }
    }
    
    func clear() {
        if (self.navigationController?.topViewController == self) {
            self.presentedViewController?.dismiss(animated: false, completion: nil)
        }
    }
    
    func ok() {
        client.ackFlowEndedAndBack { (_, state) in
            DispatchQueue.main.async {
                self.stateChanged(state: state)
            }
        }
    }
    
    func pairCancel() {
        if client.state.txFlowState != nil {
            let alertVC = UIAlertController(title: "Pairing", message: client.state.pairingFlowState.message, preferredStyle: .alert)
            let cancelBtn = UIAlertAction(title: "Cancel", style: .default) { (_) in
                self.client.pairingCancel()
            }
            alertVC.addAction(cancelBtn)
            showAlert(alertController: alertVC)
        }
    }
    
    func txCancel() {
        let alertVC = UIAlertController(title: "Transaction", message: client.state.txFlowState.displayMessage, preferredStyle: .alert)
        
        if client.state.txFlowState.type != .settleEnquiry {
            let cancelBtn = UIAlertAction(title: "Cancel", style: .default) { (_) in
                self.client.cancelTransaction()
            }
            alertVC.addAction(cancelBtn)
        }
        
        showAlert(alertController: alertVC)
    }
    
    func txAuthCode() {
        var txtAuthCode: UITextField?
        let alertVC = UIAlertController(title: "Auth Code", message: "Submit Phone for Auth Code", preferredStyle: .alert)
        _ = alertVC.addTextField { (txt) in
            txtAuthCode = txt
            txt.text = "Enter code"
        }
        let submitBtn = UIAlertAction(title: "Submit", style: .default) { (_) in
            self.client.submitAuthCode(txtAuthCode?.text, completion: { (result) in
                self.logMessage(String(format: "Valid format: %@)", result?.isValidFormat ?? false))
                self.logMessage(String(format: "Message: %@", result?.message ?? "-"))
            })
        }
        alertVC.addAction(submitBtn)
        showAlert(alertController: alertVC)
    }
    
    func txSignature() {
        let alertVC = UIAlertController(title: "Signature", message: "Select Action", preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Accept Signature", style: .default, handler: { _ in
            RamenApp.current.client.acceptSignature(true)
        }))
        alertVC.addAction(UIAlertAction(title: "Decline Signature", style: .default, handler: { _ in
            RamenApp.current.client.acceptSignature(false)
        }))
        showAlert(alertController: alertVC)
    }
    
}
