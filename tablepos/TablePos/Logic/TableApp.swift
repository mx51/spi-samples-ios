//
//  TableContext.swift
//  TablePos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation
import SPIClient_iOS

class TableApp: NSObject {
    
    private static var _instance: TableApp = TableApp()
    
    var settings = SettingsProvider()
    var client = SPIClient()
    var spiPat = SPIPayAtTable()
    
    var billsStore = [String: Bill] ()
    var tableToBillMapping = [String: String] ()
    var mx51BillDataStore = [String: String] ()
    var allowedOperatorIds: Array<String> = Array()
    
    static var current: TableApp {
        return _instance
    }
    
    func initialize() {
        client.eftposAddress = settings.eftposAddress
        client.posId = settings.posId
        client.config.signatureFlowOnEftpos = settings.customerSignatureromEftpos ?? false
        client.config.promptForCustomerCopyOnEftpos = settings.customerReceiptFromEftpos ?? false
        
        client.posVendorId = "mx51"
        client.posVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        client.delegate = self
        spiPat = client.enablePayAtTable()
        enablePayAtTableConfig()
        spiPat.config.labelTableId = "Table Number"
        spiPat.delegate = self
        
        if let encriptionKey = settings.encriptionKey, let hmacKey = settings.hmacKey, encriptionKey != "", hmacKey != "" {
            SPILogMsg("Secrets loaded from defaults: \(encriptionKey):\(hmacKey)")
            
            client.setSecretEncKey(encriptionKey, hmacKey: hmacKey)
        }
        
        let docsBaseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tableToBillMappingUrl = docsBaseURL.appendingPathComponent("tableToBillMapping.bin")
        let billsStoreUrl = docsBaseURL.appendingPathComponent("billsStore.bin")
        let mx51BillDataStoreUrl = docsBaseURL.appendingPathComponent("mx51BillDataStore.bin")
        
        let filePath = tableToBillMappingUrl.path
        let fileManager = FileManager.default       
        
        if fileManager.fileExists(atPath: filePath) {
            tableToBillMapping = NSKeyedUnarchiver.unarchiveObject(withFile: tableToBillMappingUrl.path) as! [String : String]
            billsStore = (NSKeyedUnarchiver.unarchiveObject(withFile: billsStoreUrl.path) as? [String : Bill])!
            mx51BillDataStore = NSKeyedUnarchiver.unarchiveObject(withFile: mx51BillDataStoreUrl.path) as! [String : String]
        }
    } 
    
    func start() {
        client.start()
    }
    
    func persistState() {
        let docsBaseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tableToBillMappingUrl = docsBaseURL.appendingPathComponent("tableToBillMapping.bin")
        let billsStoreUrl = docsBaseURL.appendingPathComponent("billsStore.bin")
        let mx51BillDataStoreUrl = docsBaseURL.appendingPathComponent("mx51BillDataStore.bin")
        
        NSKeyedArchiver.archiveRootObject(tableToBillMapping as NSDictionary, toFile: tableToBillMappingUrl.path)
        NSKeyedArchiver.archiveRootObject(billsStore as NSDictionary, toFile: billsStoreUrl.path)
        NSKeyedArchiver.archiveRootObject(mx51BillDataStore as NSDictionary, toFile: mx51BillDataStoreUrl.path)
    }
    
    func writeToFile(fileUrl: URL, dict: NSDictionary) {
        let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [])
        let jsonString = String(data: jsonData!, encoding: .utf8)
        try? jsonString?.write(to: fileUrl, atomically: true, encoding: .utf8)
    }
    
    func enablePayAtTableConfig() {
        spiPat.config.payAtTableEnabled = true
        spiPat.config.operatorIdEnabled = true
        spiPat.config.allowedOperatorIds = allowedOperatorIds
        spiPat.config.equalSplitEnabled = true
        spiPat.config.splitByAmountEnabled = true
        spiPat.config.summaryReportEnabled = true
        spiPat.config.tippingEnabled = true
        spiPat.config.labelOperatorId = "Operator ID"
        spiPat.config.labelPayButton = "Pay at Table"
        spiPat.config.labelTableId = "Table Number"
        spiPat.config.tableRetrievalEnabled = true
        
        settings.patEnabled = spiPat.config.payAtTableEnabled
        settings.operatorIdEnabled = spiPat.config.operatorIdEnabled
        settings.equalSplit = spiPat.config.equalSplitEnabled
        settings.splitByAmount = spiPat.config.splitByAmountEnabled
        settings.tipping = spiPat.config.tippingEnabled
        settings.summaryReport = spiPat.config.summaryReportEnabled
        settings.tableRetrievalButton = spiPat.config.tableRetrievalEnabled
        settings.labelPayButton = spiPat.config.labelPayButton
        settings.labelTableId = spiPat.config.labelTableId
        settings.labelOperatorId = spiPat.config.labelOperatorId
    }
}
