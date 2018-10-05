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
        
        if let encriptionKey = settings.encriptionKey, let hmacKey = settings.hmacKey {
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
            //            tableToBillMapping =  NSDictionary(contentsOf: tableToBillMappingUrl) as! [String : String]
            //            billsStore =  NSDictionary(contentsOf: billsStoreUrl) as! [String : Bill]
            //            assemblyBillDataStore =  NSDictionary(contentsOf: assemblyBillDataStoreUrl) as! [String : String]
            
            tableToBillMapping = NSKeyedUnarchiver.unarchiveObject(withFile: tableToBillMappingUrl.path) as! [String : String]
            billsStore = (NSKeyedUnarchiver.unarchiveObject(withFile: billsStoreUrl.path) as? [String : Bill])!
            assemblyBillDataStore = NSKeyedUnarchiver.unarchiveObject(withFile: assemblyBillDataStoreUrl.path) as! [String : String]
            
            //            var jsonString = try? String(contentsOf: tableToBillMappingUrl, encoding: .utf8)
            //            var jsonData = jsonString?.data(using: .utf8)
            //            tableToBillMapping = try! JSONSerialization.jsonObject(with: jsonData!, options: .mutableLeaves) as! [String : String]
            //
            //            jsonString = try? String(contentsOf: billsStoreUrl, encoding: .utf8)
            //            jsonData = jsonString?.data(using: .utf8)
            //            billsStore = try! JSONSerialization.jsonObject(with: jsonData!, options: .mutableLeaves) as! [String : AnyObject]
            //
            //            jsonString = try? String(contentsOf: assemblyBillDataStoreUrl, encoding: .utf8)
            //            jsonData = jsonString?.data(using: .utf8)
            //            assemblyBillDataStore = try! JSONSerialization.jsonObject(with: jsonData!, options: .mutableLeaves) as! [String : String]
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
        
        //        writeToFile(fileUrl: tableToBillMappingUrl, dict: tableToBillMapping as NSDictionary)
        //        writeToFile(fileUrl: billsStoreUrl, dict: billsStore as NSDictionary)
        //        writeToFile(fileUrl: assemblyBillDataStoreUrl, dict: assemblyBillDataStore as NSDictionary)
        
        //        let tableToBillMappingData:NSData = NSKeyedArchiver.archivedData(withRootObject: tableToBillMapping) as NSData
        //        let billsStoreData:NSData = NSKeyedArchiver.archivedData(withRootObject: billsStore) as NSData
        //        let assemblyBillDataStoreData:NSData = NSKeyedArchiver.archivedData(withRootObject: assemblyBillDataStore) as NSData
        
        NSKeyedArchiver.archiveRootObject(tableToBillMapping as NSDictionary, toFile: tableToBillMappingUrl.path)
        NSKeyedArchiver.archiveRootObject(billsStore as NSDictionary, toFile: billsStoreUrl.path)
        NSKeyedArchiver.archiveRootObject(assemblyBillDataStore as NSDictionary, toFile: assemblyBillDataStoreUrl.path)
        
        //        (tableToBillMapping as NSDictionary).write(toFile: tableToBillMappingUrl.path, atomically: true)
        //        (billsStore as NSDictionary).write(toFile: billsStoreUrl.path, atomically: true)
        //        (assemblyBillDataStore as NSDictionary).write(toFile: assemblyBillDataStoreUrl.path, atomically: true)
        
        //        NSDictionary(dictionary: tableToBillMapping).write(to: tableToBillMappingUrl, atomically: true)
        //        NSDictionary(dictionary: billsStore).write(to: billsStoreUrl, atomically: true)
        //        NSDictionary(dictionary: assemblyBillDataStore).write(to: assemblyBillDataStoreUrl, atomically: true)
    }
    
    func writeToFile(fileUrl: URL, dict: NSDictionary) {
        let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [])
        let jsonString = String(data: jsonData!, encoding: .utf8)
        try? jsonString?.write(to: fileUrl, atomically: true, encoding: .utf8)
    }
}
