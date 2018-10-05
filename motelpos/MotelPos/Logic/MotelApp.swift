//
//  MotelContext.swift
//  MotelPos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

class MotelApp: NSObject {
    
    private static var _instance: MotelApp = MotelApp()
    
    var settings = SettingsProvider()
    var client = SPIClient()
    var spiPreauth = SPIPreAuth()

    static var current: MotelApp {
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
        spiPreauth = client.enablePreauth()
        
        if let encriptionKey = settings.encriptionKey, let hmacKey = settings.hmacKey {
            SPILogMsg("Secrets loaded from defaults: \(encriptionKey):\(hmacKey)")
            
            client.setSecretEncKey(encriptionKey, hmacKey: hmacKey)
        }
    }
    
    func start() {
        client.start()
    }
    
}
