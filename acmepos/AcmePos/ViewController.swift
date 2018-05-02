//
//  ViewController.swift
//  AcmePos
//
//  Created by Yoo-Jin Lee on 2017-11-30.
//  Copyright © 2017 Mokten Pty Ltd. All rights reserved.
//

import UIKit
import PMAlertController
import SPIClient_iOS

class ViewController: UIViewController {
    static let txTitle = "EFTPOS - Purchase XYZ"

    @IBOutlet var posIdTextField: UITextField!
    @IBOutlet var eftposTextField: UITextField!
    @IBOutlet var posEftposBtn: UIButton!

    @IBOutlet var pairStatusView: UIView!
    @IBOutlet var pairStatusLabel: UILabel!
    @IBOutlet var pairStatusBtn: UIButton!

    @IBOutlet var stateTextView: UITextView!
    @IBOutlet var receiptTextView: UITextView!
    @IBOutlet var buttonsStackView: UIStackView!

    var spi = SPIClient()

    var state: SPIState? {
        didSet {
            self.stateDescription = description(for:state)
            self.updatePairStatusView(state?.status ?? .unpaired)
        }
    }
    
    var stateDescription = ""

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "ACME-POS: New Integrated Payment Solution"
        definesPresentationContext = true

        let posId = UserDefaults.standard.string(forKey: "posId") ?? "ACMEPOS3TEST"
        let eftposAddress = UserDefaults.standard.string(forKey: "eftposAddress") ?? "emulator-prod.herokuapp.com"
        
        spi.eftposAddress = eftposAddress;
        spi.posId = posId;

        posIdTextField.text = posId
        eftposTextField.text = eftposAddress.replacingOccurrences(of: "ws://", with: "")

        if let encKey = UserDefaults.standard.string(forKey: "encKey"),
            let hmacKey = UserDefaults.standard.string(forKey: "hmacKey") {
            SPILogMsg("LOADED KEYS FROM USERDEFAULTS")
            SPILogMsg("KEYS \(encKey):\(hmacKey)")
            spi.setSecretEncKey(encKey, hmacKey: hmacKey)
        }

        spi.delegate = self
        spi.start() // should only be called once here only after instantiation.
    }

    @IBAction func savePosEftpos() {
        spi.eftposAddress = eftposTextField.text
        spi.posId = posIdTextField.text
        UserDefaults.standard.set(eftposTextField.text, forKey: "eftposAddress")
        UserDefaults.standard.set(posIdTextField.text, forKey: "posId")
    }

    // MARK: - View Helper
    func description(for state: SPIState?) -> String {
        SPILogMsg("======updateStateView=====")

        var buffer = ""
        if let state = state {
            buffer += "flow: \(SPIState.flowString(state.flow)!)\n"

            if state.flow == .pairing, let pairingFlowState = state.pairingFlowState {
                buffer += "isAwaitingCheckFromEftpos: \(pairingFlowState.isAwaitingCheckFromEftpos)\n"
                buffer += "isAwaitingCheckFromPos: \(pairingFlowState.isAwaitingCheckFromPos)\n"
                buffer += "isFinished: \(pairingFlowState.isFinished)\n"
                buffer += "isSuccessful: \(pairingFlowState.isSuccessful)\n"
            } else if state.flow == .transaction, let txFlowState = state.txFlowState  {
                buffer += txFlowStateString(txFlowState)
            }
        }

        return buffer
    }

    func updatePairStatusView(_ status: SPIStatus) {
        SPILogMsg("UPDATING PAIR STATUS VIEW")
        dispatch() { [weak self] in
            guard let `self` = self else { return }
            switch status {
            case .unpaired:
                self.pairStatusLabel.text = "STATUS: UNPAIRED"
                self.pairStatusBtn.setTitle("PAIR", for: .normal)
                self.posIdTextField.isEnabled = true
                self.eftposTextField.isEnabled = true
                self.posEftposBtn.isEnabled = true
                self.buttonsStackView.isHidden = true

            case .pairedConnecting:
                self.pairStatusLabel.text = "STATUS: PAIRED BUT TRYING TO CONNECT"
                self.pairStatusBtn.setTitle("UNPAIR", for: .normal)
                self.posIdTextField.isEnabled = false
                self.eftposTextField.isEnabled = true
                self.posEftposBtn.isEnabled = true
                self.buttonsStackView.isHidden = false

            case .pairedConnected:
                self.pairStatusLabel.text = "STATUS: PAIRED AND CONNECTED"
                self.pairStatusBtn.setTitle("UNPAIR", for: .normal)
                self.posIdTextField.isEnabled = false
                self.eftposTextField.isEnabled = false
                self.posEftposBtn.isEnabled = false
                self.buttonsStackView.isHidden = false

            }
        }
    }

    // MARK: - Pair

    @IBAction func togglePair() {
        SPILogMsg("togglePair")

        if pairStatusBtn.titleLabel?.text == "PAIR" {
            pair()
        } else {
            unpair()
        }

    }

    func pair() {
        SPILogMsg("vc pair")
        savePosEftpos()
        spi.pair()
    }

    func showPairing(_ state: SPIState) {
        SPILogMsg("showPairing")

        guard let pairingFlowState = state.pairingFlowState else {
            return showError("Missing pairingFlowState \(state)")
        }

        showAlert("EFTPOS PAIRING PROCESS", message: pairingFlowState.message) { alertVC in

            if pairingFlowState.isAwaitingCheckFromPos {
                SPILogMsg("# [pair_confirm] - confirm the code matches")

                alertVC.addAction(PMAlertAction(title: "NO", style: .cancel) { [weak self] in
                        guard let `self` = self else { return }
                        self.pairingCancel()
                    })

                alertVC.addAction(PMAlertAction(title: "YES", style: .default, action: { [weak self] in
                    guard let `self` = self else { return }
                    self.spi.pairingConfirmCode()
                }), dismiss: false)

            } else if !pairingFlowState.isFinished {
                SPILogMsg("# [pair_cancel] - cancel pairing process")

                alertVC.addAction(PMAlertAction(title: "CANCEL", style: .cancel, action: { [weak self] in
                    guard let `self` = self else { return }
                    self.pairingCancel()
                }), dismiss: false)

            } else if pairingFlowState.isSuccessful {
                SPILogMsg("# [ok] - acknowledge pairing")

                alertVC.addAction(PMAlertAction(title: "OK", style: .default, action: { [weak self] in
                    guard let `self` = self else { return }
                    self.acknowledge()
                }))

            } else {
                // error
                alertVC.addAction(PMAlertAction(title: "OK", style: .default, action: nil))
            }
        }
    }
    
    @IBAction func pairingCancel() {
        spi.pairingCancel()
    }

    func acknowledge() {
        SPILogMsg("acknowledge")

        spi.ackFlowEndedAndBack { [weak self] alreadyMovedToIdleState, state in
            guard let `self` = self else { return }
            self.state = state
            self.printStatusAndAction(state)
        }
    }

    func unpair() {
        SPILogMsg("unpair")
        spi.unpair()
    }

    // MARK: - Transactions

    @IBAction func showPurchase() {
        SPILogMsg("showPurchase")

        showAlert(ViewController.txTitle, message: "Please enter the amount you would like to purchase for in cents") { alertVC in

            alertVC.addTextField({ textField in
                textField?.placeholder = "Amount (cents)"
            })

            alertVC.addAction(PMAlertAction(title: "Purchase", style: .default, action: { [weak self] in
                guard let `self` = self else { return }

                let purchaseTextField = alertVC.textFields[0] as UITextField

                self.spi.initiatePurchaseTx(SPIRequestIdHelper.id(for: "prchs"), amountCents: Int(purchaseTextField.text!) ?? 0, completion: { pres in
                        guard let pres = pres else { return }
                        SPILogMsg(pres.isInitiated ? "# Purchase Initiated. Will be updated with Progress." : "# Could not initiate purchase: \(pres.message). Please Retry.")
                    })

            }), dismiss: false)

            alertVC.addAction(PMAlertAction(title: "Cancel", style: .cancel))
        }

    }

    func showConnectedTx(_ state: SPIState) {
        SPILogMsg("showConnectedTx")

        guard let txFlowState = state.txFlowState else {
            showError("Missing txFlowState \(state)")
            return
        }

        showAlert(ViewController.txTitle, message: txFlowState.displayMessage) { alertVC in

            if (txFlowState.successState == .failed) {
                SPILogMsg("# [ok] - acknowledge fail")

                alertVC.addAction(PMAlertAction(title: "OK", style: .default, action: { [weak self] in
                    guard let `self` = self else { return }
                    self.acknowledge()
                }))

            } else {

                if txFlowState.isAwaitingSignatureCheck {
                    SPILogMsg("# [tx_sign_accept] - Accept Signature")
                    SPILogMsg("# [tx_sign_decline] - Decline Signature")

                    alertVC.addAction(PMAlertAction(title: "Accept Signature", style: .default, action: { [weak self] in
                        self?.spi.acceptSignature(true)
                    }), dismiss: false)

                    alertVC.addAction(PMAlertAction(title: "Decline Signature", style: .default, action: { [weak self] in
                        self?.spi.acceptSignature(false)
                    }), dismiss: false)
                }

                if !txFlowState.isFinished {
                    SPILogMsg("# [tx_cancel] - Attempt to Cancel Transaction")

                    if !state.txFlowState.isAttemptingToCancel {
                        alertVC.addAction(PMAlertAction(title: "Cancel", style: .default, action: { [weak self] in
                            self?.spi.cancelTransaction()
                        }), dismiss: false)
                    }

                } else {
                    SPILogMsg("# [ok] - acknowledge transaction success")

                    alertVC.addAction(PMAlertAction(title: "OK", style: .default, action: { [weak self] in
                        guard let `self` = self else { return }
                        self.acknowledge()
                    }))
                }
            }
        }

    }

    @IBAction func showRefund() {

        showAlert("EFTPOS - Refund", message: "Please enter the amount you would like to refund for in cents") { alertVC in

            alertVC.addTextField({ (textField: UITextField!) -> Void in
                textField.placeholder = "Amount (cents)"
            })

            alertVC.addAction(PMAlertAction(title: "Refund", style: .default, action: { [weak self] in
                guard let `self` = self else { return }

                let purchaseTextField = alertVC.textFields[0] as UITextField

                self.spi.initiateRefundTx(SPIRequestIdHelper.id(for: "rfnd"), amountCents: Int(purchaseTextField.text!) ?? 100, completion: { pres in
                        guard let pres = pres else { return }
                        self.alertCancelTx(ViewController.txTitle, message: pres.isInitiated ? "# Refund Initiated. Will be updated with Progress." : "# Could not initiate refund: \(pres.message). Please Retry.")
                    })

            }), dismiss: false)

            alertVC.addAction(PMAlertAction(title: "Cancel", style: .cancel))
        }
    }

    @IBAction func showSettle() {
        spi.initiateSettleTx(SPIRequestIdHelper.id(for: "settle"), completion: { [weak self] pres in
                guard let pres = pres, let `self` = self else { return }

                self.showAlert("EFTPOS - ", message: pres.isInitiated ? "# Settle Initiated. Will be updated with Progress." : "# Could not initiate settle: \(pres.message). Please Retry.")

            })
    }
    
    @IBAction func showGetLastTx() {
        spi.initiateGetLastTx(completion: { [weak self] pres in
            guard let pres = pres, let `self` = self else { return }
            
            self.showAlert("EFTPOS - ", message: pres.isInitiated ? "# Get Last Transaction Initiated. Will be updated with Progress." : "# Could not initiate get last transaction: \(pres.message). Please Retry.")
            
        })
    }
    

// MARK: - Alert Helpers
    
    func showAlert(_ title: String = "", message: String = "", handler: ((PMAlertController) -> ())? = nil) {
        alert(title,
              message: message + "\n\n======= STATUS ========\n" + stateDescription + "====================",
              handler:handler)
    }

    func alert(_ title: String = "", message: String = "") {

        showAlert(title, message: message) { alertVC in
            alertVC.addAction(PMAlertAction(title: "OK", style: .cancel))
        }
    }
    
    func alertCancelTx(_ title: String = "", message: String = "") {
        showAlert(title, message: message) { alertVC in
            alertVC.addAction(PMAlertAction(title: "Cancel", style: .cancel, action: { [weak self] in
                self?.spi.cancelTransaction()
            }), dismiss: false)
        }
        
    }

    func alertAcknowledge(_ title: String = "", message: String = "") {
        showAlert(title, message: message) { alertVC in
            alertVC.addAction(PMAlertAction(title: "OK", style: .default, action: { [weak self] in
                guard let `self` = self else { return }
                self.acknowledge()
            }))
        }
    }

    func showError(_ msg: String, completion: (() -> Swift.Void)? = nil) {
        SPILogMsg("ERROR: \(msg)")
        showAlert("ERROR!", message: msg)
    }

    func appendReceipt(_ msg: String?) {
        SPILogMsg("appendReceipt \(String(describing: msg))")

        guard let msg = msg, msg.count > 0 else { return }

        dispatch() { [weak self] in
            guard let hardSelf = self else { return }
            hardSelf.receiptTextView.text = msg + "\n================\n" + hardSelf.receiptTextView.text
        }
    } 

}

extension ViewController {

    // MARK: - Helpers

    func printStatusAndAction(_ state: SPIState?) {
        SPILogMsg("printStatusAndAction \(String(describing: state))")

        guard let state = state else { return }

        switch state.status {

        case .unpaired:

            switch state.flow {
            case .idle:
                SPILogMsg("# [pos_id:MYPOSNAME] - sets your POS instance ID")
                SPILogMsg("# [eftpos_address:10.10.10.10] - sets IP address of target EFTPOS")
                SPILogMsg("# [pair] - start pairing")

            case .pairing:
                showPairing(state)

            default:
                showError("# .. Unexpected Flow .. \(state.flow.rawValue)")
            }

        case .pairedConnecting, .pairedConnected:
            SPILogMsg("status .connected, flow=\(state.flow.rawValue)")

            switch state.flow {
            case .idle:
                break

            case .transaction:
                showConnectedTx(state)

            case .pairing: // Paired, Pairing - we have just finished the pairing flow. OK to ack.
                showPairing(state)
            }
        }
    }
}

// MARK: - SPIDelegate

extension ViewController: SPIDelegate {

    
    /// Called when we received a Status Update i.e. Unpaired/PairedConnecting/PairedConnected
    func spi(_ spi: SPIClient, statusChanged state: SPIState) {

        SPILogMsg("statusChanged \(state)")
        self.state = state
        self.printStatusAndAction(state)
    }
    
    // Called during the pairing process to let us know how it's going.
    // We just update our screen with the information, and provide relevant Actions to the user.
    func spi(_ spi: SPIClient, pairingFlowStateChanged state: SPIState) {
        SPILogMsg("pairingFlowStateChanged \(state)")
        self.state = state
        self.printStatusAndAction(state)
    }

    func spi(_ spi: SPIClient!, secretsChanged secrets: SPISecrets?, state: SPIState!) {
        SPILogMsg("secrets \(state)")

        if let secrets = secrets {
            SPILogMsg("\n\n\n# --------- I GOT NEW SECRETS -----------")
            SPILogMsg("# ---------- PERSIST THEM SAFELY ----------")
            SPILogMsg("# \(secrets.encKey):\(secrets.hmacKey)")
            SPILogMsg("# -----------------------------------------")

            // In prod store them in the key chain
            UserDefaults.standard.set(secrets.encKey, forKey: "encKey")
            UserDefaults.standard.set(secrets.hmacKey, forKey: "hmacKey")
        } else {
            SPILogMsg("\n\n\n# --------- THE SECRETS HAVE BEEN VOIDED -----------")
            SPILogMsg("# ---------- CONSIDER ME UNPAIRED ----------")
            SPILogMsg("# -----------------------------------------")

            UserDefaults.standard.removeObject(forKey: "encKey")
            UserDefaults.standard.removeObject(forKey: "hmacKey")
        }
    }

    // Called during a transaction to let us know how it's going.
    // We just update our screen with the information, and provide relevant Actions to the user.
    func spi(_ spi: SPIClient, transactionFlowStateChanged state: SPIState) {
        SPILogMsg("transactionFlowStateChanged \(state)")

        self.state = state
        
        // Let's show the user what options he has at this stage.
        printStatusAndAction(state)
    }
    
    func txFlowStateString(_ txFlowState: SPITransactionFlowState) -> String {
        var buffer = "# Id: \(txFlowState.tid ?? "")\n"
        buffer += "# Type: \(SPITransactionFlowState.txTypeString(txFlowState.type)!)\n"
        buffer += "# RequestSent: \(txFlowState.isRequestSent)\n"
        buffer += "# WaitingForSignature: \(txFlowState.isAwaitingSignatureCheck)\n"
        buffer += "# Attempting to Cancel: \(txFlowState.isAttemptingToCancel)\n"
        buffer += "# Finished: \(txFlowState.isFinished)\n"
        buffer += "# Success: \(SPIMessage.successState(toString:txFlowState.successState)!)\n"
        buffer += "# Display Message: \(txFlowState.displayMessage ?? "")\n"
        
        if txFlowState.isAwaitingSignatureCheck {
            // We need to print the receipt for the customer to sign.
            self.appendReceipt(txFlowState.signatureRequiredMessage.getMerchantReceipt())
        }
        
        // If the transaction is finished, we take some extra steps.
        if txFlowState.isFinished {
            
            if txFlowState.successState == .unknown {
                // TH-4T, TH-4N, TH-2T - This is the dge case when we can't be sure what happened to the transaction.
                // Invite the merchant to look at the last transaction on the EFTPOS using the dicumented shortcuts.
                // Now offer your merchant user the options to:
                // A. Retry the transaction from scrtatch or pay using a different method - If Merchant is confident that tx didn't go through.
                // B. Override Order as Paid in you POS - If Merchant is confident that payment went through.
                // C. Cancel out of the order all together - If the customer has left / given up without paying
                buffer += "# NOT SURE IF WE GOT PAID OR NOT. CHECK LAST TRANSACTION MANUALLY ON EFTPOS!\n"
                buffer += "# RETRY (TH-5R), OVERRIDE AS PAID (TH-5D), CANCEL (TH-5C)\n"
            } else {
                
                // We have a result...
                switch txFlowState.type {
                    // Depending on what type of transaction it was, we might act diffeently or use different data.
                    
                case .purchase:
                    
                    if txFlowState.response != nil {
                        if let purchaseResponse = SPIPurchaseResponse(message: txFlowState.response) {
                            buffer += "# Scheme: \(purchaseResponse.schemeName)\n"
                            buffer += "# Response: \(purchaseResponse.getText() ?? "")\n"
                            buffer += "# RRN: \(purchaseResponse.getRRN() ?? "")\n"
                            
                            if let error = txFlowState.response.error {
                                buffer += "# Error: \(error)\n"
                            }
                            
                            self.appendReceipt(purchaseResponse.getCustomerReceipt())
                        }
                    } else {
                        // We did not even get a response, like in the case of a time-out.
                    }
                    
                    if txFlowState.isFinished && txFlowState.successState == .success {
                        // TH-6A
                        buffer += "# HOORAY WE GOT PAID (TH-7A). CLOSE THE ORDER!\n"
                        
                    } else {
                        // TH-6E
                        buffer += "# WE DIDN'T GET PAID. RETRY PAYMENT (TH-5R) OR GIVE UP (TH-5C)!\n"
                    }
                    
                case .refund:
                    if txFlowState.response != nil {
                        if let refundResponse = SPIRefundResponse(message: txFlowState.response) {
                            buffer += "# Scheme: \(refundResponse.schemeName)\n"
                            buffer += "# Response: \(refundResponse.getText)\n"
                            buffer += "# RRN: \(refundResponse.getRRN)\n"
                            buffer += "# Customer Receipt:\n"
                            self.appendReceipt(refundResponse.getCustomerReceipt())
                        }
                        
                        if let error = txFlowState.response.error {
                            buffer += "# Error: \(error)\n"
                        }
                        
                    } else {
                        // We did not even get a response, like in the case of a time-out.
                    }
                    
                case .settle:
                    
                    if let response = txFlowState.response, let settleResponse = SPISettlement(message: response) {
                        buffer += "# Response: \(settleResponse.getResponseText())\n"
                        
                        if let error = txFlowState.response.error {
                            buffer += "# Error: \(error)\n"
                        }
                        
                        self.appendReceipt(settleResponse.getReceipt())
                    } else {
                        // We did not even get a response, like in the case of a time-out.
                    }
                    
                case .getLastTransaction:
                    
                    if let response = txFlowState.response, let gltResponse = SPIGetLastTransactionResponse(message: response) {
                        buffer += "# Type: \(gltResponse.getTxType())\n"
                        buffer += "# Amount: \(gltResponse.getAmount())\n"
                        buffer += "# Success State: \(gltResponse.successState)\n"
                        
                        if let error = txFlowState.response.error {
                            buffer += "# Error: \(error)\n"
                        }
                    } else {
                        // We did not even get a response, like in the case of a time-out.
                    }
                }
            }
        }
        
        return buffer
    }
    
}
