//
//  MainViewController.swift
//  MotelPos
//
//  Created by Amir Kamali on 27/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import UIKit
import SPIClient_iOS

class MainViewController: UITableViewController, NotificationListener {

    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var lblPosId: UILabel!
    @IBOutlet weak var lblPosAddress: UILabel!
    @IBOutlet weak var lblPreauthId: UILabel!
    @IBOutlet weak var btnConnection: UIBarButtonItem!
    @IBOutlet weak var txtTransactionAmount: UITextField!
    @IBOutlet weak var txtPreauthId: UITextField!
    @IBOutlet weak var txtReferenceId: UITextField!
    @IBOutlet weak var txtOutput: UITextView!
    @IBOutlet weak var swchReceiptFromEftpos: UISwitch!
    @IBOutlet weak var swchSignatureFromEftpos: UISwitch!
    @IBOutlet weak var swchPrintMerchantCopy: UISwitch!
    @IBOutlet weak var lblFlowStatus: UILabel!
    @IBOutlet weak var txtHeader: UITextField!
    @IBOutlet weak var txtFooter: UITextField!
    
    let _lastCmd: [String] = []
    
    var client: SPIClient {
        return MotelApp.current.client
    }
    
    var spiPreauth: SPIPreAuth {
        return MotelApp.current.spiPreauth
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        restoreConfig()

        registerForEvents(appEvents: [.connectionStatusChanged, .transactionFlowStateChanged])
        client.start()
    }
    
    func restoreConfig() {
        let settings = MotelApp.current.settings
        
        swchReceiptFromEftpos.isOn = settings.customerReceiptFromEftpos ?? false
        swchSignatureFromEftpos.isOn = settings.customerSignatureromEftpos ?? false
        swchPrintMerchantCopy.isOn = settings.printMerchantCopy ?? false
        txtHeader.text = settings.receiptHeader
        txtFooter.text = settings.receiptFooter
    }

    // MARK: - Table view data source
   
    @IBAction func swchReceiptFromEFTPOSValueChanged(_ sender: UISwitch) {
        client.config.promptForCustomerCopyOnEftpos = sender.isOn
        MotelApp.current.settings.customerReceiptFromEftpos = sender.isOn
    }

    @IBAction func swchSignatureFromEFTPOSValueChanged(_ sender: UISwitch) {
        client.config.signatureFlowOnEftpos = sender.isOn
        MotelApp.current.settings.customerSignatureromEftpos = sender.isOn
    }
    
    @IBAction func swchPrintMerchantCopyValueChanged(_ sender: UISwitch) {
        client.config.printMerchantCopy = sender.isOn
        MotelApp.current.settings.printMerchantCopy = sender.isOn
    }
    
    @IBAction func txtHeaderEditingDidEnd(_ sender: UITextField) {
        MotelApp.current.settings.receiptHeader = sanitizeHeaderFooter(sender.text)
    }
    
    @IBAction func txtFooterEditingDidEnd(_ sender: UITextField) {
        MotelApp.current.settings.receiptFooter = sanitizeHeaderFooter(sender.text)
    }
    
    private func sanitizeHeaderFooter(_ text: String?) -> String? {
        return text?.replacingOccurrences(of: "\\r\\n", with: "\r\n")
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
    
}
