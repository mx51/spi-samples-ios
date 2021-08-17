//
//  RamenContext.swift
//  RamenPos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 mx51. All rights reserved.
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
        let posVendorId = "mx51"
        let deviceApiKey = "RamenPosDeviceAddressApiKey"
        let countryCode = "AU"
        
        SPIClient.getAvailableTenants(posVendorId, apiKey: deviceApiKey, countryCode: countryCode) { (data) in
            if (data != nil) {
                self.settings.tenantList = (data as? Array<Dictionary<String, String>>)!
                self.settings.tenantList.append(["code": "other", "name": "Other"])
            }
        }

        client.eftposAddress = settings.eftposAddress
        client.posId = settings.posId

        client.testMode = settings.testMode ?? false
        client.serialNumber = settings.serialNumber

        client.config.signatureFlowOnEftpos = settings.customerSignatureFromEftpos ?? false
        client.config.promptForCustomerCopyOnEftpos = settings.customerReceiptFromEftpos ?? false

        client.posVendorId = posVendorId
        client.posVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        client.acquirerCode = settings.tenant
        client.deviceApiKey = deviceApiKey

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
