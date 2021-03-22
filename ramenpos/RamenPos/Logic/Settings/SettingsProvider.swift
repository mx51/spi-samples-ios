//
//  SettingsProvider.swift
//  RamenPos
//
//  Created by Amir Kamali on 27/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation

class SettingsProvider {
    
    enum SettingKeys: String {
        case apiKey
        case countryCode
        case posId
        case eftposAddress
        case encriptionKey
        case hmacKey
        case customerReceipt
        case customerSignature
        case printMerchantCopy
        case receiptHeader
        case receiptFooter
        case printText
        case posVendorKey
        case testMode
        case autoResolution
        case suppressMerchantPassword
        case serialNumber
        case tenant
        case tenantList
    }
    
    private var defaultTenants = [
        ["code": "wbc", "name": "Westpac Presto"],
        ["code": "till", "name": "Till Payments"],
        ["code": "other", "name": "Other"]
    ]
    
    init() {
        restoreDefaultValues()
    }
    
    func readSettingsFrom(key: SettingKeys) -> Any? {
        return UserDefaults.standard.value(forKey: key.rawValue)
    }
    
    func setSettingsForKey(key: SettingKeys, value: Any?) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
        UserDefaults.standard.synchronize()
    }
    
    func restoreDefaultValues() {
        if (UserDefaults.standard.value(forKey: SettingKeys.posId.rawValue) == nil) {
            countryCode = "AU"
            posId = "RAMENPOS1"
            eftposAddress = "emulator-prod.herokuapp.com"
            tenantList = defaultTenants
        }
    }

    var apiKey: String? {
        get { return readSettingsFrom(key: .apiKey) as? String }
        set { setSettingsForKey(key: .apiKey, value: newValue) }
    }

    var countryCode: String? {
        get { return readSettingsFrom(key: .countryCode) as? String }
        set { setSettingsForKey(key: .countryCode, value: newValue) }
    }

    var encriptionKey: String? {
        get { return readSettingsFrom(key: .encriptionKey) as? String }
        set { setSettingsForKey(key: .encriptionKey, value: newValue) }
    }
    
    var posId: String? {
        get { return readSettingsFrom(key: .posId) as? String }
        set { setSettingsForKey(key: .posId, value: newValue) }
    }
    
    var eftposAddress: String? {
        get { return readSettingsFrom(key: .eftposAddress) as? String }
        set { setSettingsForKey(key: .eftposAddress, value: newValue) }
    }
    
    var hmacKey: String? {
        get { return readSettingsFrom(key: .hmacKey) as? String }
        set { setSettingsForKey(key: .hmacKey, value: newValue) }
    }
    
    var customerReceiptFromEftpos: Bool? {
        get { return readSettingsFrom(key: .customerReceipt) as? Bool }
        set { setSettingsForKey(key: .customerReceipt, value: newValue) }
    }
    
    var customerSignatureFromEftpos: Bool? {
        get { return readSettingsFrom(key: .customerSignature) as? Bool }
        set { setSettingsForKey(key: .customerSignature, value: newValue) }
    }
    
    var printMerchantCopy: Bool? {
        get { return readSettingsFrom(key: .printMerchantCopy) as? Bool }
        set { setSettingsForKey(key: .printMerchantCopy, value: newValue) }
    }
    
    var receiptHeader: String? {
        get { return readSettingsFrom(key: .receiptHeader) as? String }
        set { setSettingsForKey(key: .receiptHeader, value: newValue) }
    }
    
    var receiptFooter: String? {
        get { return readSettingsFrom(key: .receiptFooter) as? String }
        set { setSettingsForKey(key: .receiptFooter, value: newValue) }
    }
    
    var printText: String? {
        get { return readSettingsFrom(key: .printText) as? String }
        set { setSettingsForKey(key: .printText, value: newValue) }
    }
    
    var posVendorKey: String? {
        get { return readSettingsFrom(key: .posVendorKey) as? String }
        set { setSettingsForKey(key: .posVendorKey, value: newValue) }
    }
    
    var testMode: Bool? {
        get { return readSettingsFrom(key: .testMode) as? Bool }
        set { setSettingsForKey(key: .testMode, value: newValue) }
    }
    
    var autoResolution: Bool? {
        get { return readSettingsFrom(key: .autoResolution) as? Bool }
        set { setSettingsForKey(key: .autoResolution, value: newValue) }
    }
    
    var suppressMerchantPassword: Bool? {
        get { return readSettingsFrom(key: .suppressMerchantPassword) as? Bool }
        set { setSettingsForKey(key: .suppressMerchantPassword, value: newValue) }
    }
    
    var serialNumber: String? {
        get { return readSettingsFrom(key: .serialNumber) as? String }
        set { setSettingsForKey(key: .serialNumber, value: newValue) }
    }
    
    var tenant: String? {
        get { return readSettingsFrom(key: .tenant) as? String }
        set { setSettingsForKey(key: .tenant, value: newValue) }
    }
    
    var tenantList: Array<Dictionary<String, String>> {
        get { return readSettingsFrom(key: .tenantList) as? Array<Dictionary<String, String>> ?? defaultTenants }
        set { setSettingsForKey(key: .tenantList, value: newValue) }
    }
}
