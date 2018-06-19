//
//  MainViewController.swift
//  kebabPos
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
    @IBOutlet weak var swchReceiptFromEFTPos: UISwitch!
    @IBOutlet weak var swchSignatureFromEFTPos: UISwitch!

    let indexPath_extraAmount = IndexPath(row: 2, section: 3)
    let _lastCmd: [String] = []

    @IBOutlet weak var lbl_flowStatus: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        restoreConfig()

        registerForEvents(appEvents: [.connectionStatusChanged, .transactionFlowStateChanged])
        client.start()
    }
    func restoreConfig() {
        swchReceiptFromEFTPos.isOn = KebabApp.current.settings.customerReceiptFromEFTPos ?? false
        swchSignatureFromEFTPos.isOn = KebabApp.current.settings.customerSignatureromEFTPos ?? false

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        KebabApp.current.settings.customerReceiptFromEFTPos = sender.isOn
    }

    @IBAction func swchSignatureFromEFTPOSValueChanged(_ sender: UISwitch) {
        client.config.signatureFlowOnEftpos = sender.isOn
        KebabApp.current.settings.customerSignatureromEFTPos = sender.isOn
    }

    var client: SPIClient {
        return KebabApp.current.client
    }
    @objc
    func onNotificationArrived(notification: NSNotification) {
        switch notification.name.rawValue {
        case AppEvent.connectionStatusChanged.rawValue:
            guard let state = notification.object as? SPIState else {
                return
            }
            DispatchQueue.main.async {
                self.stateChanged(state: state)
            }
        case AppEvent.transactionFlowStateChanged.rawValue:
            guard let state = notification.object as? SPIState else {
                return
            }
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
        showAlert(title: "ERROR!", message: msg)

    }
}
