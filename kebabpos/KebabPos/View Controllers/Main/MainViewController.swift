//
//  MainViewController.swift
//  KebabPos
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
    
    let indexPath_extraAmount = IndexPath(row: 2, section: 3)
    let _lastCmd: [String] = []
    
    var client: SPIClient {
        return KebabApp.current.client
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        restoreConfig()

        registerForEvents(appEvents: [.connectionStatusChanged, .transactionFlowStateChanged])
        client.start()
    }
    
    func restoreConfig() {
        let settings = KebabApp.current.settings
        
        swchReceiptFromEftpos.isOn = settings.customerReceiptFromEftpos ?? false
        swchSignatureFromEftpos.isOn = settings.customerSignatureromEftpos ?? false
        swchPrintMerchantCopy.isOn = settings.printMerchantCopy ?? false
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
        KebabApp.current.settings.customerReceiptFromEftpos = sender.isOn
    }

    @IBAction func swchSignatureFromEFTPOSValueChanged(_ sender: UISwitch) {
        client.config.signatureFlowOnEftpos = sender.isOn
        KebabApp.current.settings.customerSignatureromEftpos = sender.isOn
    }
    
    @IBAction func swchPrintMerchantCopyValueChanged(_ sender: UISwitch) {
        client.config.printMerchantCopy = sender.isOn
        KebabApp.current.settings.printMerchantCopy = sender.isOn
    }
    
    @IBAction func txtHeaderEditingDidEnd(_ sender: UITextField) {
        KebabApp.current.settings.receiptHeader = sanitizeHeaderFooter(sender.text)
    }
    
    @IBAction func txtFooterEditingDidEnd(_ sender: UITextField) {
        KebabApp.current.settings.receiptFooter = sanitizeHeaderFooter(sender.text)
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
