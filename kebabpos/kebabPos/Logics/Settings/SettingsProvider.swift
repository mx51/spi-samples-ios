//
//  SettingsProvider.swift
//  kebabPos
//
//  Created by Amir Kamali on 27/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation

class SettingsProvider {
    enum SettingKeys: String {
        case posId
        case eftposAddress
        case encriptionKey
        case hmacKey
        case customerReceipt
        case customerSignature
    }
    init() {
        restoreDefaultValues()
    }
    func ReadSettingsFrom(key: SettingKeys) -> Any? {
        return UserDefaults.standard.value(forKey: key.rawValue)
    }
    func SetSettingsForKey(key: SettingKeys, value: Any?) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
        UserDefaults.standard.synchronize()
    }
    func restoreDefaultValues() {
        if (UserDefaults.standard.value(forKey: SettingKeys.posId.rawValue) == nil) {
            posId = "ACMEPOS3TEST"
            eftPosAddress = "10.20.11.44"//"emulator-prod.herokuapp.com"
        }

    }
    var encriptionKey: String? {
        get {return ReadSettingsFrom(key: .encriptionKey) as? String }
        set {SetSettingsForKey(key: .encriptionKey, value: newValue) }
    }
    var posId: String? {
        get {return ReadSettingsFrom(key: .posId) as? String }
        set {SetSettingsForKey(key: .posId, value: newValue) }
    }
    var eftPosAddress: String? {
        get {return ReadSettingsFrom(key: .eftposAddress) as? String }
        set {SetSettingsForKey(key: .eftposAddress, value: newValue) }
    }
    var hmacKey: String? {
        get {return ReadSettingsFrom(key: .hmacKey) as? String }
        set {SetSettingsForKey(key: .hmacKey, value: newValue) }
    }
    var customerReceiptFromEFTPos: Bool? {
        get {return ReadSettingsFrom(key: .customerReceipt) as? Bool }
        set {SetSettingsForKey(key: .customerReceipt, value: newValue) }
    }
    var customerSignatureromEFTPos: Bool? {
        get {return ReadSettingsFrom(key: .customerSignature) as? Bool }
        set {SetSettingsForKey(key: .customerSignature, value: newValue) }
    }
}
