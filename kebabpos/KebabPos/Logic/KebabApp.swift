//
//  KebabContext.swift
//  KebabPos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation
import SPIClient_iOS

class KebabApp: NSObject {
    
    private static var _instance: KebabApp = KebabApp()
    
    var settings = SettingsProvider()
    var client = SPIClient()

    static var current: KebabApp {
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
        
        if let encriptionKey = settings.encriptionKey, let hmacKey = settings.hmacKey {
            SPILogMsg("Secrets loaded from defaults: \(encriptionKey):\(hmacKey)")
            
            client.setSecretEncKey(encriptionKey, hmacKey: hmacKey)
        }
    }
    
    func start() {
        client.start()
    }
    
}
