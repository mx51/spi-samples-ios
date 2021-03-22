//
//  ConnectionViewController.swift
//  RamenPos
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
    @IBOutlet weak var txtSerialNumber: UITextField!
    @IBOutlet weak var swchTestModeValue: UISwitch!
    @IBOutlet weak var swchAutoResolution: UISwitch!
    @IBOutlet weak var btnPair: UIButton!
    @IBOutlet weak var btnUnpair: UIButton!
    @IBOutlet weak var btnCancelPair: UIButton!
    @IBOutlet weak var btnSave: UIButton!
    
    private var pkrTenant = UIPickerView()

    var client: SPIClient {
        return RamenApp.current.client
    }
    
    var isUnnpaired = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerForEvents(appEvents: [.connectionStatusChanged, .pairingFlowChanged, .transactionFlowStateChanged, .secretsDropped, .deviceAddressChanged])
        
        let settings = RamenApp.current.settings
        
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

        txtPosId.text = RamenApp.current.settings.posId
        txtPosAddress.text = RamenApp.current.settings.eftposAddress
        txtSerialNumber.text = RamenApp.current.settings.serialNumber
        swchAutoResolution.isOn = RamenApp.current.settings.autoResolution ?? false
        swchTestModeValue.isOn = RamenApp.current.settings.testMode ?? false
    }
    
    @IBAction func pairButtonClicked(_ sender: Any) {
        if (client.state.status != .unpaired ) {
            showAlert(title: "Cannot start pairing", message: "SPI Client status: \(RamenApp.current.client.state.status.name)")
            return
        }
        
        if (!areControlsValid(isPairing: true)) {
            return
        }
        
        let settings = RamenApp.current.settings
        settings.autoResolution = swchAutoResolution.isOn
        settings.testMode = swchTestModeValue.isOn
        settings.tenant = txtTenant.text != "Other" ? getTenantCode(tenantName: txtTenant.text!) : txtOtherTenant.text
        settings.posId = txtPosId.text
        settings.eftposAddress = txtPosAddress.text
        settings.serialNumber = txtSerialNumber.text
        settings.encriptionKey = nil
        settings.hmacKey = nil
        
        client.autoAddressResolutionEnable = swchAutoResolution.isOn
        client.posId = txtPosId.text
        client.eftposAddress = txtPosAddress.text
        client.pair()
    }
    
    @IBAction func pairingCancel() {
        RamenApp.current.client.pairingCancel()
    }
    
    @IBAction func unpair() {
        RamenApp.current.client.unpair()
        isUnnpaired = true
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        if (client.state.status == SPIStatus.pairedConnected) {
            return
        }
        
        if (!areControlsValid(isPairing: false)) {
            return
        }
        
        if (isUnnpaired && swchAutoResolution.isOn) {
            client.posId = ""
            client.eftposAddress = ""
            client.serialNumber = ""
            isUnnpaired = false
        }
        
        btnSave.isEnabled = false
        RamenApp.current.client.acquirerCode = txtTenant.text != "Other" ? getTenantCode(tenantName: txtTenant.text!) : txtOtherTenant.text
        RamenApp.current.client.testMode = swchTestModeValue.isOn
        RamenApp.current.client.autoAddressResolutionEnable = swchAutoResolution.isOn
        RamenApp.current.client.serialNumber = txtSerialNumber.text
        
        let alertVC = UIAlertController(title: "Device Address Info", message: "Device Address Service is waiting for response...", preferredStyle: .alert)
        self.showAlert(alertController: alertVC)
    }
    
    @IBAction func swchTestModeValueChanged(_ sender: UISwitch) {
        RamenApp.current.settings.autoResolution = sender.isOn
        RamenApp.current.settings.testMode = swchTestModeValue.isOn
    }
    
    @IBAction func swchAutoResolutionValueChanged(_ sender: UISwitch) {
        if (!sender.isOn) {
            swchTestModeValue.isOn = false
            swchTestModeValue.isEnabled = false
            btnSave.isEnabled = false
        } else {
            swchTestModeValue.isOn = true
            swchTestModeValue.isEnabled = true
            btnSave.isEnabled = true
        }
        
        RamenApp.current.settings.autoResolution = sender.isOn
        RamenApp.current.settings.testMode = swchTestModeValue.isOn
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
                
            case AppEvent.deviceAddressChanged.rawValue:
                if let state = notification.object as? SPIState {
                    self.deviceAddressStatusAndAction(state)
                }
                
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
                RamenApp.current.client.ackFlowEndedAndBack { (alreadyInIdle, state) in
                    print("Setting to idle=\(alreadyInIdle) state=\(String(describing: state))")
                    if let state = state {
                        self.showPairing(state)
                    }
                }
            default:
                showError("Unexpected flow: \(RamenApp.current.client.state.flow.rawValue)")
            }
            
        case .pairedConnecting, .pairedConnected:
            SPILogMsg("Status .connected, flow=\(state.flow.rawValue)")
            
            switch state.flow {
            case .idle, .transaction:
                break
            case .pairing: // Paired, Pairing - we have just finished the pairing flow. OK to ack.
                showPairing(RamenApp.current.client.state)
            default:
                break
            }
            
        default:
            break
        }
    }
    
    func deviceAddressStatusAndAction(_ state: SPIState?) {
        SPILogMsg("deviceAddressStatusAndAction \(String(describing: state))")
        btnSave.isEnabled = true
        guard let state = state else { return }
        
        let alertVC: UIAlertController
        
        if (state.deviceAddressStatus != nil) {
            switch state.deviceAddressStatus.deviceAddressResponseCode {
            case .DeviceAddressResponseCodeSuccess:
                txtPosAddress.text = state.deviceAddressStatus.address
                alertVC = UIAlertController(title: "Device Address Status", message: "- Device Address has been updated to \(state.deviceAddressStatus.address ?? "")", preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    SPILogMsg("# [ok] ")
                }))
            case .DeviceAddressResponseCodeInvalidSerialNumber:
                txtPosAddress.text = ""
                alertVC = UIAlertController(title: "Device Address Error", message: "The serial number is invalid!", preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    SPILogMsg("# [ok] ")
                }))
            case .DeviceAddressResponseCodeAddressNotChanged:
                alertVC = UIAlertController(title: "Device Address Error", message: "The IP address have not changed!", preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    SPILogMsg("# [ok] ")
                }))
            case .DeviceAddressResponseCodeSerialNumberNotChanged:
                alertVC = UIAlertController(title: "Device Address Error", message: "The serial number have not changed!", preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    SPILogMsg("# [ok] ")
                }))
            case .DeviceAddressResponseCodeDeviceError:
                txtPosAddress.text = ""
                alertVC = UIAlertController(title: "Device Address Error", message: "The device service error! \(state.deviceAddressStatus.responseCode)", preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    SPILogMsg("# [ok] ")
                }))
            default:
                txtPosAddress.text = ""
                alertVC = UIAlertController(title: "Device Address Error", message: "The device service error! \(state.deviceAddressStatus.responseCode)", preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    SPILogMsg("# [ok] ")
                }))
            }
            
            self.showAlert(alertController: alertVC)
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
                
                RamenApp.current.client.pairingConfirmCode()
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
        
        RamenApp.current.client.ackFlowEndedAndBack {  _, state in
            self.printStatusAndAction(RamenApp.current.client.state)
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
    
    func areControlsValid(isPairing: Bool) -> Bool {
        if ((txtTenant.text ?? "").isEmpty) {
            showError("Please select a Payment Provider")
            return false
        }
        
        if (txtTenant.text == "Other" && (txtOtherTenant.text ?? "").isEmpty) {
            showError("Please enter an other payment provider code")
            return false
        }

        if (isPairing && (txtPosAddress.text ?? "").isEmpty) {
            showError("Please enable auto address resolution or enter a device address!")
            return false
        }
        
        if ((txtPosId.text ?? "").isEmpty) {
            showError("Please provide a Pos Id")
            return false
        }
        
        if (!isPairing && RamenApp.current.settings.autoResolution! && (txtSerialNumber.text ?? "").isEmpty) {
            showError("Please provide a Serial Number")
            return false
        }
        
        return true
    }
    
    func getTenantCode(tenantName: String) -> String? {
        return RamenApp.current.settings.tenantList.first(where:{$0["name"] == tenantName})!["code"]
    }
}

extension ConnectionViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return RamenApp.current.settings.tenantList.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return RamenApp.current.settings.tenantList[row]["name"]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedTenantName = RamenApp.current.settings.tenantList[row]["name"]
        let isOtherTenantSelected = selectedTenantName == "Other"

        txtTenant.text = RamenApp.current.settings.tenantList[row]["name"]

        if (!isOtherTenantSelected) { txtOtherTenant.text = "" }
        txtOtherTenant.isEnabled = isOtherTenantSelected

        txtTenant.resignFirstResponder()
    }
}
