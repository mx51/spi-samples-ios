//
//  ConnectionViewController.swift
//  KebabPos
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
        
        registerForEvents(appEvents: [.connectionStatusChanged, .pairingFlowChanged, .transactionFlowStateChanged, .secretsDropped])
        
        txtPosId.text = KebabApp.current.settings.posId
        txtPosAddress.text = KebabApp.current.settings.eftposAddress
    }
    
    @IBAction func pairButtonClicked(_ sender: Any) {
        let client = KebabApp.current.client
        
        if (client.state.status != .unpaired ) {
            showAlert(title: "Cannot start pairing", message: "SPI Client status: \(KebabApp.current.client.state.status.name)")
            return
        }
        
        let settings = KebabApp.current.settings
        settings.posId = txtPosId.text
        settings.eftposAddress = txtPosAddress.text
        settings.encriptionKey = nil
        settings.hmacKey = nil
        
        client.posId = txtPosId.text
        client.eftposAddress = txtPosAddress.text
        client.pair()
    }
    
    @IBAction func pairingCancel() {
        KebabApp.current.client.pairingCancel()
    }
    
    @IBAction func unpair() {
        KebabApp.current.client.unpair()
    }

    @objc
    func onNotificationArrived(notification: NSNotification) {
        DispatchQueue.main.async {
            switch notification.name.rawValue {
            case AppEvent.connectionStatusChanged.rawValue,
                 AppEvent.pairingFlowChanged.rawValue,
                 AppEvent.transactionFlowStateChanged.rawValue:
                
                if let state = notification.object as? SPIState {
                    self.printStatusAndAction(state)
                }
                
            case AppEvent.secretsDropped.rawValue:
                self.showAlert(title: "Pairing", message: "Secrets have been dropped")
                
            default:
                return
            }
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
                    print("Setting to idle=\(alreadyInIdle) state=\(String(describing: state))")
                    if let state = state {
                        self.showPairing(state)
                    }
                }
            default:
                showError("Unexpected flow: \(KebabApp.current.client.state.flow.rawValue)")
            }
            
        case .pairedConnecting, .pairedConnected:
            SPILogMsg("Status .connected, flow=\(state.flow.rawValue)")
            
            switch state.flow {
            case .idle, .transaction:
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
        
        let alertVC = UIAlertController(title: "EFTPOS Pairing Process", message: pairingFlowState.message, preferredStyle: .alert)

        if pairingFlowState.isAwaitingCheckFromPos {
            alertVC.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (_) in
                SPILogMsg("# [pair_cancel] - cancel pairing process")
                
                self.pairingCancel()
            }))

            alertVC.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                SPILogMsg("# [pair_confirm] - confirm the code matches")
                
                KebabApp.current.client.pairingConfirmCode()
            }))

        } else if !pairingFlowState.isFinished {
            alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                SPILogMsg("# [pair_cancel] - cancel pairing process")
                
                self.pairingCancel()
            }))

        } else if pairingFlowState.isSuccessful {
            alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                SPILogMsg("# [ok] - acknowledge pairing")
                
                self.acknowledge()
            }))

        } else {
            // error
            alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        
        self.showAlert(alertController: alertVC)
    }

    func acknowledge() {
        SPILogMsg("acknowledge")

        KebabApp.current.client.ackFlowEndedAndBack {  _, state in
            self.printStatusAndAction(KebabApp.current.client.state)
        }
    }

    func showError(_ msg: String, completion: (() -> Swift.Void)? = nil) {
        SPILogMsg("ERROR: \(msg)")
        
        showAlert(title: "Error", message: msg)
    }
    
    func appendReceipt(_ msg: String?) {
        SPILogMsg("appendReceipt \(String(describing: msg))")

        guard let msg = msg, msg.count > 0 else { return }

        DispatchQueue.main.async {
            self.txtOutput.text = msg + "\n================\n" + self.txtOutput.text
        }
    }
    
}
