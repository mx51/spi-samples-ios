//
//  MainViewController.swift
//  RamenPos
//
//  Created by Amir Kamali on 27/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import UIKit
import SPIClient_iOS

class MainViewController: UITableViewController, NotificationListener {
    
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var lblPosId: UILabel!
    @IBOutlet weak var lblPosAddress: UILabel!
    @IBOutlet weak var lblExtraOption: UILabel!
    @IBOutlet weak var btnConnection: UIBarButtonItem!
    @IBOutlet weak var txtTransactionAmount: UITextField!
    @IBOutlet weak var txtExtraAmount: UITextField!
    @IBOutlet weak var txtReferenceId: UITextField!
    @IBOutlet weak var txtOutput: UITextView!
    @IBOutlet weak var segmentExtraAmount: UISegmentedControl!
    @IBOutlet weak var swchReceiptFromEftpos: UISwitch!
    @IBOutlet weak var swchSignatureFromEftpos: UISwitch!
    @IBOutlet weak var swchPrintMerchantCopy: UISwitch!
    @IBOutlet weak var lblFlowStatus: UILabel!
    @IBOutlet weak var txtHeader: UITextField!
    @IBOutlet weak var txtFooter: UITextField!
    @IBOutlet weak var txtPosVendorKey: UITextField!
    @IBOutlet weak var txtPrintText: UITextField!
    @IBOutlet weak var lblTerminalStatus: UILabel!
    @IBOutlet weak var lblBatteryLevel: UILabel!
    @IBOutlet weak var lblCharging: UILabel!
    @IBOutlet weak var lblCommsSelected: UILabel!
    @IBOutlet weak var lblMerchantId: UILabel!
    @IBOutlet weak var lblPAVersion: UILabel!
    @IBOutlet weak var lblPaymentInterfaceVersion: UILabel!
    @IBOutlet weak var lblPluginVersion: UILabel!
    @IBOutlet weak var lblSerialNumber: UILabel!
    @IBOutlet weak var lblTerminalId: UILabel!
    @IBOutlet weak var lblTerminalModel: UILabel!
    @IBOutlet weak var swchSuppressMerchantPassword: UISwitch!
    
    var isShowingPrompt = false
    
    let indexPath_extraAmount = IndexPath(row: 2, section: 3)
    
    var client: SPIClient {
        return RamenApp.current.client
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        restoreConfig()
        
        registerForEvents(appEvents: [.connectionStatusChanged, .transactionFlowStateChanged, .printingResponse, .terminalStatusResponse, .terminalConfigurationResponse, .batteryLevelChanged])
        client.start()
    }
    
    func restoreConfig() {
        let settings = RamenApp.current.settings
        
        swchReceiptFromEftpos.isOn = settings.customerReceiptFromEftpos ?? false
        swchSignatureFromEftpos.isOn = settings.customerSignatureFromEftpos ?? false
        swchPrintMerchantCopy.isOn = settings.printMerchantCopy ?? false
        swchSuppressMerchantPassword.isOn = settings.suppressMerchantPassword ?? false
        
        txtHeader.text = settings.receiptHeader
        txtFooter.text = settings.receiptFooter
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath == indexPath_extraAmount && segmentExtraAmount.selectedSegmentIndex == 0) {
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    @IBAction func segmentExtraAmountValueChanged(_ sender: UISegmentedControl) {
        tableView.beginUpdates()
        lblExtraOption.text = segmentExtraAmount.titleForSegment(at: segmentExtraAmount.selectedSegmentIndex)
        tableView.endUpdates()
    }
    
    @IBAction func swchReceiptFromEFTPOSValueChanged(_ sender: UISwitch) {
        client.config.promptForCustomerCopyOnEftpos = sender.isOn
        RamenApp.current.settings.customerReceiptFromEftpos = sender.isOn
    }
    
    @IBAction func swchSignatureFromEFTPOSValueChanged(_ sender: UISwitch) {
        client.config.signatureFlowOnEftpos = sender.isOn
        RamenApp.current.settings.customerSignatureFromEftpos = sender.isOn
    }
    
    @IBAction func swchPrintMerchantCopyValueChanged(_ sender: UISwitch) {
        client.config.printMerchantCopy = sender.isOn
        RamenApp.current.settings.printMerchantCopy = sender.isOn
    }
    
    @IBAction func txtHeaderEditingDidEnd(_ sender: UITextField) {
        RamenApp.current.settings.receiptHeader = sender.text
    }
    
    @IBAction func txtFooterEditingDidEnd(_ sender: UITextField) {
        RamenApp.current.settings.receiptFooter = sender.text
    }
    
    @IBAction func swchSuppressMerchantPasswordValueChanged(_ sender: UISwitch) {
        RamenApp.current.settings.suppressMerchantPassword = sender.isOn
    }
    
    @objc
    func onNotificationArrived(notification: NSNotification) {
        switch notification.name.rawValue {
        case AppEvent.connectionStatusChanged.rawValue:
            guard let state = notification.object as? SPIState else { return }
            DispatchQueue.main.async {
                self.stateChanged(state: state)
            }
        case AppEvent.transactionFlowStateChanged.rawValue:
            guard let state = notification.object as? SPIState else { return }
            DispatchQueue.main.async {
                self.stateChanged(state: state)
            }
        case AppEvent.printingResponse.rawValue:
            guard let message = notification.object as? SPIMessage else { return }
            DispatchQueue.main.async {
                self.handlePrintingResponse(message: message)
            }
        case AppEvent.terminalStatusResponse.rawValue:
            guard let message = notification.object as? SPIMessage else { return }
            DispatchQueue.main.async {
                self.handleTerminalStatusResponse(message: message)
            }
        case AppEvent.terminalConfigurationResponse.rawValue:
            guard let message = notification.object as? SPIMessage else { return }
            DispatchQueue.main.async {
                self.handleTerminalConfigurationResponse(message: message)
            }
        case AppEvent.batteryLevelChanged.rawValue:
            guard let message = notification.object as? SPIMessage else { return }
            DispatchQueue.main.async {
                self.handleBatteryLevelChanged(message: message)
            }
        case AppEvent.updateMessageReceived.rawValue:
            guard let message = notification.object as? SPIMessage else { return }
            DispatchQueue.main.async {
                self.handleUpdateMessageReceived(message: message)
            }
        default:
            break
        }
    }
    
    func printResult(result: SPIInitiateTxResult?) {
        DispatchQueue.main.async {
            SPILogMsg(result?.message)
            self.txtOutput.text =  result?.message ?? "" + self.txtOutput.text
        }
    }
    
    func showError(_ msg: String, completion: (() -> Void)? = nil) {
        SPILogMsg("\r\nERROR: \(msg)")
        showAlert(title: "Error", message: msg)
    }
    
    func showActionsAlert(transaction: String, retryHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "Actions", message: "WE'RE NOT QUITE SURE WHETHER THE \(transaction) WENT THROUGH OR NOT.\nCHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM.\nYOU CAN THE TAKE THE APPROPRIATE ACTION.", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.isShowingPrompt = false
        })
        let retryAction = UIAlertAction(title: "Retry", style: .default) { _ in
            retryHandler()
            self.isShowingPrompt = false
        }
        let overrideAction = UIAlertAction(title: "Override as paid", style: .default) { _ in
            self.logMessage("# \(transaction) SUCCESSFUL")
            self.isShowingPrompt = false
        }
        alert.addAction(retryAction)
        alert.addAction(overrideAction)
        alert.addAction(cancelAction)
        isShowingPrompt = true
        showAlert(alertController: alert)
    }
    
}
