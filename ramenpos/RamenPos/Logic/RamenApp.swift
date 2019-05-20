//
//  RamenContext.swift
//  RamenPos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

class RamenApp: NSObject {
    
    private static var _instance: RamenApp = RamenApp()
    
    var settings = SettingsProvider()
    var client = SPIClient()

    static var current: RamenApp {
        return _instance
    }

    func initialize() {
        client.eftposAddress = settings.eftposAddress
        client.posId = settings.posId
        
        client.config.signatureFlowOnEftpos = settings.customerSignatureFromEftpos ?? false
        client.config.promptForCustomerCopyOnEftpos = settings.customerReceiptFromEftpos ?? false
        
        client.posVendorId = "assembly"
        client.posVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        client.acquirerCode = "wbc"
        client.deviceApiKey = "RamenPosDeviceAddressApiKey"
        
        client.delegate = self
        
        if let encriptionKey = settings.encriptionKey, let hmacKey = settings.hmacKey, encriptionKey != "", hmacKey != "" {
            SPILogMsg("Secrets loaded from defaults: \(encriptionKey):\(hmacKey)")
            
            client.setSecretEncKey(encriptionKey, hmacKey: hmacKey)
        }
    }
    
    func start() {
        client.start()
    }
    
}
