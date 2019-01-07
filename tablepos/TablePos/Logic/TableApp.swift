//
//  TableContext.swift
//  TablePos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
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
    var assemblyBillDataStore = [String: String] ()
    
    static var current: TableApp {
        return _instance
    }
    
    func initialize() {
        client.eftposAddress = settings.eftposAddress
        client.posId = settings.posId
        client.config.signatureFlowOnEftpos = settings.customerSignatureromEftpos ?? false
        client.config.promptForCustomerCopyOnEftpos = settings.customerReceiptFromEftpos ?? false
        
        client.posVendorId = "assembly"
        client.posVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        client.delegate = self
        spiPat = client.enablePayAtTable()
        spiPat.config.labelTableId = "Table Number"
        spiPat.delegate = self
        
        if let encriptionKey = settings.encriptionKey, let hmacKey = settings.hmacKey, encriptionKey != "", hmacKey != "" {
            SPILogMsg("Secrets loaded from defaults: \(encriptionKey):\(hmacKey)")
            
            client.setSecretEncKey(encriptionKey, hmacKey: hmacKey)
        }
        
        let docsBaseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tableToBillMappingUrl = docsBaseURL.appendingPathComponent("tableToBillMapping.bin")
        let billsStoreUrl = docsBaseURL.appendingPathComponent("billsStore.bin")
        let assemblyBillDataStoreUrl = docsBaseURL.appendingPathComponent("assemblyBillDataStore.bin")
        
        let filePath = tableToBillMappingUrl.path
        let fileManager = FileManager.default       
        
        if fileManager.fileExists(atPath: filePath) {
            tableToBillMapping = NSKeyedUnarchiver.unarchiveObject(withFile: tableToBillMappingUrl.path) as! [String : String]
            billsStore = (NSKeyedUnarchiver.unarchiveObject(withFile: billsStoreUrl.path) as? [String : Bill])!
            assemblyBillDataStore = NSKeyedUnarchiver.unarchiveObject(withFile: assemblyBillDataStoreUrl.path) as! [String : String]
        }
    } 
    
    func start() {
        client.start()
    }
    
    func persistState() {
        let docsBaseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tableToBillMappingUrl = docsBaseURL.appendingPathComponent("tableToBillMapping.bin")
        let billsStoreUrl = docsBaseURL.appendingPathComponent("billsStore.bin")
        let assemblyBillDataStoreUrl = docsBaseURL.appendingPathComponent("assemblyBillDataStore.bin")
        
        NSKeyedArchiver.archiveRootObject(tableToBillMapping as NSDictionary, toFile: tableToBillMappingUrl.path)
        NSKeyedArchiver.archiveRootObject(billsStore as NSDictionary, toFile: billsStoreUrl.path)
        NSKeyedArchiver.archiveRootObject(assemblyBillDataStore as NSDictionary, toFile: assemblyBillDataStoreUrl.path)
    }
    
    func writeToFile(fileUrl: URL, dict: NSDictionary) {
        let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [])
        let jsonString = String(data: jsonData!, encoding: .utf8)
        try? jsonString?.write(to: fileUrl, atomically: true, encoding: .utf8)
    }
}
