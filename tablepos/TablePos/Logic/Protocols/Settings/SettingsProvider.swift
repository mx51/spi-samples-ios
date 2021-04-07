//
//  SettingsProvider.swift
//  TablePos
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
        case suppressMerchantPassword
        case patEnabled
        case operatorIdEnabled
        case equalSplit
        case splitByAmount
        case tipping
        case summaryReport
        case tableRetrievalButton
        case labelOperatorId
        case labelTableId
        case labelPayButton
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
            posId = "TABLEPOS1"
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
    
    var customerSignatureromEftpos: Bool? {
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
    
    var suppressMerchantPassword: Bool? {
        get { return readSettingsFrom(key: .suppressMerchantPassword) as? Bool }
        set { setSettingsForKey(key: .suppressMerchantPassword, value: newValue) }
    }
    
    var patEnabled: Bool? {
        get { return readSettingsFrom(key: .patEnabled) as? Bool}
        set { setSettingsForKey(key: .patEnabled, value: newValue)}
    }
    
    var operatorIdEnabled: Bool? {
        get { return readSettingsFrom(key: .operatorIdEnabled) as? Bool}
        set { setSettingsForKey(key: .operatorIdEnabled, value: newValue)}
    }
    
    var equalSplit: Bool? {
        get { return readSettingsFrom(key: .equalSplit) as? Bool}
        set { setSettingsForKey(key: .equalSplit, value: newValue)}
    }
    
    var splitByAmount: Bool? {
        get { return readSettingsFrom(key: .splitByAmount) as? Bool}
        set { setSettingsForKey(key: .splitByAmount, value: newValue)}
    }
    
    var tipping: Bool? {
        get { return readSettingsFrom(key: .tipping) as? Bool}
        set { setSettingsForKey(key: .tipping, value: newValue)}
    }
    
    var summaryReport: Bool? {
        get { return readSettingsFrom(key: .summaryReport) as? Bool}
        set { setSettingsForKey(key: .summaryReport, value: newValue)}
    }
    
    var tableRetrievalButton: Bool? {
        get { return readSettingsFrom(key: .tableRetrievalButton) as? Bool}
        set { setSettingsForKey(key: .tableRetrievalButton, value: newValue)}
    }
    
    var labelOperatorId: String? {
        get { return readSettingsFrom(key: .labelOperatorId) as? String }
        set { setSettingsForKey(key: .labelOperatorId, value: newValue) }
    }

    var labelTableId: String? {
        get { return readSettingsFrom(key: .labelTableId) as? String }
        set { setSettingsForKey(key: .labelTableId, value: newValue) }
    }
    
    var labelPayButton: String? {
        get { return readSettingsFrom(key: .labelPayButton) as? String }
        set { setSettingsForKey(key: .labelPayButton, value: newValue) }
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
