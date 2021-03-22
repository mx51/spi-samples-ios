//
//  ConnectionViewController.swift
//  MotelPos
//
//  Created by Amir Kamali on 27/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import UIKit
import SPIClient_iOS

class ConnectionViewController: UITableViewController, NotificationListener {
    
    @IBOutlet weak var txtOutput: UITextView!
    @IBOutlet weak var txtTenant: UITextField!
    @IBOutlet weak var txtOtherTenant: UITextField!
    @IBOutlet weak var txtPosId: UITextField!
    @IBOutlet weak var txtPosAddress: UITextField!

    private var pkrTenant = UIPickerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerForEvents(appEvents: [.connectionStatusChanged, .pairingFlowChanged, .transactionFlowStateChanged, .secretsDropped])

        let settings = MotelApp.current.settings

        pkrTenant.delegate = self
        pkrTenant.dataSource = self
        txtTenant.inputView = pkrTenant

        if (settings.tenant != nil) {
            let tenantName = settings.tenantList.first(where:{$0["code"] == settings.tenant})?["name"]

            if (tenantName != nil) {
                txtTenant.text = tenantName
                txtOtherTenant.isEnabled = false
                pkrTenant.selectRow(settings.tenantList.firstIndex(where:{$0["code"] == settings.tenant}) ?? 0, inComponent: 0, animated: false)
            } else {
                txtTenant.text = "Other"
                txtOtherTenant.isEnabled = true
                txtOtherTenant.text = settings.tenant
                pkrTenant.selectRow(settings.tenantList.firstIndex(where:{$0["code"] == "other"}) ?? 0, inComponent: 0, animated: false)
            }
        }

        txtPosId.text = MotelApp.current.settings.posId
        txtPosAddress.text = MotelApp.current.settings.eftposAddress
    }
    
    @IBAction func pairButtonClicked(_ sender: Any) {
        let client = MotelApp.current.client
        
        if (client.state.status != .unpaired ) {
            showAlert(title: "Cannot start pairing", message: "SPI Client status: \(MotelApp.current.client.state.status.name)")
            return
        }
        
        let settings = MotelApp.current.settings
        settings.tenant = txtTenant.text != "Other" ? getTenantCode(tenantName: txtTenant.text!) : txtOtherTenant.text
        settings.posId = txtPosId.text
        settings.eftposAddress = txtPosAddress.text
        settings.encriptionKey = nil
        settings.hmacKey = nil

        client.acquirerCode = settings.tenant
        client.posId = txtPosId.text
        client.eftposAddress = txtPosAddress.text
        client.pair()
    }
    
    @IBAction func pairingCancel() {
        MotelApp.current.client.pairingCancel()
    }
    
    @IBAction func unpair() {
        MotelApp.current.client.unpair()
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
                MotelApp.current.client.ackFlowEndedAndBack { (alreadyInIdle, state) in
                    print("Setting to idle=\(alreadyInIdle) state=\(String(describing: state))")
                    if let state = state {
                        self.showPairing(state)
                    }
                }
            default:
                showError("Unexpected flow: \(MotelApp.current.client.state.flow.rawValue)")
            }
            
        case .pairedConnecting, .pairedConnected:
            SPILogMsg("Status .connected, flow=\(state.flow.rawValue)")
            
            switch state.flow {
            case .idle, .transaction:
                break
            case .pairing: // Paired, Pairing - we have just finished the pairing flow. OK to ack.
                showPairing(MotelApp.current.client.state)
            default:
                break
            }
            
        default:
            break
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
                
                MotelApp.current.client.pairingConfirmCode()
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
        
        MotelApp.current.client.ackFlowEndedAndBack {  _, state in
            self.printStatusAndAction(MotelApp.current.client.state)
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
    
    func getTenantCode(tenantName: String) -> String? {
        return MotelApp.current.settings.tenantList.first(where:{$0["name"] == tenantName})!["code"]
    }
}

extension ConnectionViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return MotelApp.current.settings.tenantList.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return MotelApp.current.settings.tenantList[row]["name"]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedTenantName = MotelApp.current.settings.tenantList[row]["name"]
        let isOtherTenantSelected = selectedTenantName == "Other"

        txtTenant.text = MotelApp.current.settings.tenantList[row]["name"]

        if (!isOtherTenantSelected) { txtOtherTenant.text = "" }
        txtOtherTenant.isEnabled = isOtherTenantSelected

        txtTenant.resignFirstResponder()
    }
}
