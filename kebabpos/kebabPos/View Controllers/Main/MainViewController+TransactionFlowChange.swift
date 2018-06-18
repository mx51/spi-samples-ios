//
//  MainViewController+TransactionFlowChange.swift
//  kebabPos
//
//  Created by Amir Kamali on 3/6/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    func updateUIFlowInfo(state: SPIState) {
        lblStatus.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        lblStatus.textColor = UIColor.darkGray

        btnConnection.title = "Pair"
        switch state.status {
        case .pairedConnected:
            lblStatus.text = "Connected"
            lblStatus.font = UIFont.systemFont(ofSize: 14, weight: UIFontWeightSemibold)
            lblStatus.textColor = UIColor(red: 23.0/256, green: 156.0/255, blue: 63.0/255, alpha: 1.0)
            btnConnection.title = "Connection"
        case .pairedConnecting:
            lblStatus.text = "Connecting"
            break
        case .unpaired:
            lblStatus.text = "Not Connected"
            break
        }
        lblPosId.text = KebabApp.current.settings.posId
        lblPosAddress.text = KebabApp.current.settings.eftPosAddress
        lbl_flowStatus.text = state.flow.name
        self.title = lblStatus.text
    }
    func stateChanged(state: SPIState? = nil) {
        guard let state = state ?? KebabApp.current.client.state else {
            return
        }
        updateUIFlowInfo(state: state)
        printFlowInfo(state: state)
        selectActions(state: state)
    }
    func selectActions(state: SPIState) {

        if client.state.flow == .idle {
            //clear UI
            self.presentedViewController?.dismiss(animated: false, completion: nil)
        }
        if (client.state.flow == .pairing) {
            if (client.state.pairingFlowState.isAwaitingCheckFromPos) {
                client.pairingConfirmCode()
            }
            if (!client.state.pairingFlowState.isFinished) {
                pair_cancel()
            }
            if (client.state.pairingFlowState.isFinished) {
                ok()
            }
        }
        if client.state.flow == .transaction, let txState = client.state.txFlowState {

            if (txState.isAwaitingSignatureCheck) {
               tx_signature()
            }
            if (txState.isAwaitingPhoneForAuth) {
                tx_auth_code()
            }
        }

        if (client.state.flow == .transaction) {

            if (!client.state.txFlowState.isFinished && !client.state.txFlowState.isAttemptingToCancel) {
               tx_cancel()
            }

            if (client.state.txFlowState.isFinished) {
                ok()
            }
        }
    }
    func ok() {
        client.ackFlowEndedAndBack { (_, state) in
            DispatchQueue.main.async {
                self.stateChanged(state: state)
            }
        }
    }
    func tx_cancel() {
        let alertVC = UIAlertController(title: "Message", message: client.state.txFlowState.displayMessage, preferredStyle: .alert)
        let cancelBtn = UIAlertAction(title: "Cancel", style: .default) { (_) in
            self.client.cancelTransaction()
        }
        alertVC.addAction(cancelBtn)
        showAlert(alertController: alertVC)

    }
    func pair_cancel() {
        let alertVC = UIAlertController(title: "Message", message: client.state.txFlowState.displayMessage, preferredStyle: .alert)
        let cancelBtn = UIAlertAction(title: "Cancel", style: .default) { (_) in
            self.client.pairingCancel()
        }
        alertVC.addAction(cancelBtn)
        showAlert(alertController: alertVC)

    }
    func tx_auth_code() {
        var txtAuthCode: UITextField?
        let alertVC = UIAlertController(title: "Message", message: "Submit Phone for Auth Code", preferredStyle: .alert)
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
    func tx_signature() {
        let alertVC = UIAlertController(title: "Message", message: "Select Action", preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Accept Signature", style: .default, handler: { _ in
        KebabApp.current.client.acceptSignature(true)
                                }))

        alertVC.addAction(UIAlertAction(title: "Decline Signature", style: .default, handler: { _ in
                                    KebabApp.current.client.acceptSignature(false)
                                }))
        showAlert(alertController: alertVC)
    }
}
