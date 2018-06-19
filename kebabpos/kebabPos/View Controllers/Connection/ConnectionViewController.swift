//
//  ConnectionViewController.swift
//  kebabPos
//
//  Created by Amir Kamali on 27/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import UIKit
import SPIClient_iOS

class ConnectionViewController: UITableViewController, NotificationListener {
    @IBOutlet weak var txtOutput: UITextView!
    @IBOutlet weak var txtPosId: UITextField!
    @IBOutlet weak var txtPosAddress: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        registerForEvents(appEvents: [.connectionStatusChanged, .pairingFlowChanged, .transactionFlowStateChanged])
        txtPosId.text = KebabApp.current.settings.posId
        txtPosAddress.text = KebabApp.current.settings.eftPosAddress

    }
    @IBAction func pairButtonClicked(_ sender: Any) {
        KebabApp.current.settings.posId = txtPosId.text
        KebabApp.current.client.posId = txtPosId.text

        KebabApp.current.settings.eftPosAddress = txtPosAddress.text
        KebabApp.current.client.eftposAddress = txtPosAddress.text

        KebabApp.current.settings.encriptionKey = nil
        KebabApp.current.settings.hmacKey = nil

        KebabApp.current.client.pair()
    }
    @IBAction func pairingCancel() {
        KebabApp.current.client.pairingCancel()
    }
    @IBAction func unpair() {
        KebabApp.current.client.unpair()
    }

    @objc
    func onNotificationArrived(notification: NSNotification) {
        switch notification.name.rawValue {
        case AppEvent.connectionStatusChanged.rawValue:
            if let state = notification.object as? SPIState {
                printStatusAndAction(state)
            }
        case AppEvent.pairingFlowChanged.rawValue:
            if let state = notification.object as? SPIState {
                printStatusAndAction(state)
            }
        case AppEvent.transactionFlowStateChanged.rawValue:
            if let state = notification.object as? SPIState {
                printStatusAndAction(state)
            }
        default:
            return
        }
    }

    func printStatusAndAction(_ state: SPIState?) {
        SPILogMsg("printStatusAndAction \(String(describing: state))")

        guard let state = state else { return }

        switch state.status {

        case .unpaired:

            switch state.flow {
            case .idle:
                break
            case .pairing:
                KebabApp.current.client.ackFlowEndedAndBack { (alreadyInIdle, state) in
                    print("setting to idle :\(alreadyInIdle) state:\(String(describing: state))")
                    if let state = state {
                        self.showPairing(state)
                    }
                }

            default:
                showError("# .. Unexpected Flow .. \(KebabApp.current.client.state.flow.rawValue)")
            }

        case .pairedConnecting, .pairedConnected:
            SPILogMsg("status .connected, flow=\(state.flow.rawValue)")

            switch state.flow {
            case .idle:
                break

            case .transaction:
                //No transaction will be in this screen
                break
            case .pairing: // Paired, Pairing - we have just finished the pairing flow. OK to ack.
                showPairing(KebabApp.current.client.state)
            }
        }
    }
    func showPairing(_ state: SPIState) {
        SPILogMsg("showPairing")

        guard let pairingFlowState = state.pairingFlowState else {
            return showError("Missing pairingFlowState \(state)")
        }
        let alertVC = UIAlertController(title: "EFTPOS PAIRING PROCESS", message: pairingFlowState.message, preferredStyle: .alert)

        if pairingFlowState.isAwaitingCheckFromPos {
            SPILogMsg("# [pair_confirm] - confirm the code matches")

            alertVC.addAction(UIAlertAction(title: "NO", style: .cancel, handler: { (_) in
                self.pairingCancel()
            }))

            alertVC.addAction(UIAlertAction(title: "YES", style: .default, handler: { _ in
                KebabApp.current.client.pairingConfirmCode()
            }))

        } else if !pairingFlowState.isFinished {
            SPILogMsg("# [pair_cancel] - cancel pairing process")

            alertVC.addAction(UIAlertAction(title: "CANCEL", style: .cancel, handler: { _ in
                self.pairingCancel()
            }))

        } else if pairingFlowState.isSuccessful {
            SPILogMsg("# [ok] - acknowledge pairing")

            alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.acknowledge()
            }))

        } else {
            // error
            alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        DispatchQueue.main.async {
            self.showAlert(alertController: alertVC)
        }

    }

    func acknowledge() {
        SPILogMsg("acknowledge")

        KebabApp.current.client.ackFlowEndedAndBack {  _, state in
            self.printStatusAndAction(KebabApp.current.client.state)
        }
    }

    func showError(_ msg: String, completion: (() -> Swift.Void)? = nil) {
        SPILogMsg("ERROR: \(msg)")
        showAlert(title: "ERROR!", message: msg)

    }
    func appendReceipt(_ msg: String?) {
        SPILogMsg("appendReceipt \(String(describing: msg))")

        guard let msg = msg, msg.count > 0 else { return }

        DispatchQueue.main.async {
            self.txtOutput.text = msg + "\n================\n" + self.txtOutput.text
        }
    }
}
