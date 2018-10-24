//
//  SPIConnectionDelegate.swift
//  RamenPos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension RamenApp: SPIDelegate {
    
    /// Called when we received a Status Update i.e. Unpaired/PairedConnecting/PairedConnected
    func spi(_ spi: SPIClient, statusChanged state: SPIState) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.connectionStatusChanged.rawValue), object: state)
        
        SPILogMsg("statusChanged \(state)")
    }
    
    // Called during the pairing process to let us know how it's going.
    // We just update our screen with the information, and provide relevant Actions to the user.
    func spi(_ spi: SPIClient, pairingFlowStateChanged state: SPIState) {
        SPILogMsg("pairingFlowStateChanged \(state)")
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.pairingFlowChanged.rawValue), object: state)
    }
    
    func spi(_ spi: SPIClient!, secretsChanged secrets: SPISecrets?, state: SPIState!) {
        SPILogMsg("secrets \(String(describing: state))")
        
        if let secrets = secrets {
            SPILogMsg("\n\n")
            SPILogMsg("# ----------- I GOT NEW SECRETS -----------")
            SPILogMsg("# ---------- PERSIST THEM SAFELY ----------")
            SPILogMsg("# \(String(describing: secrets.encKey)):\(String(describing: secrets.hmacKey))")
            SPILogMsg("# -----------------------------------------")
            
            // In prod store them in the key chain
            settings.encriptionKey = secrets.encKey
            settings.hmacKey = secrets.hmacKey
        } else {
            SPILogMsg("\n\n")
            SPILogMsg("# ------ THE SECRETS HAVE BEEN VOIDED -----")
            SPILogMsg("# ---------- CONSIDER ME UNPAIRED ---------")
            SPILogMsg("# -----------------------------------------")
            
            settings.encriptionKey = ""
            settings.hmacKey = ""
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.secretsDropped.rawValue), object: state)
        }
    }
    
    // Called during a transaction to let us know how it's going.
    // We just update our screen with the information, and provide relevant Actions to the user.
    func spi(_ spi: SPIClient, transactionFlowStateChanged state: SPIState) {
        SPILogMsg("transactionFlowStateChanged \(state)")
        
        // Let's show the user what options he has at this stage.
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.transactionFlowStateChanged.rawValue), object: state)
    }
    
    func printingResponse(_ message: SPIMessage!) {
        SPILogMsg("printingResponse")
        
        // Let's show the user what options he has at this stage.
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.printingResponse.rawValue), object: message)
    }
    
    func terminalStatusResponse(_ message: SPIMessage!) {
        SPILogMsg("terminalStatusResponse")
        
        // Let's show the user what options he has at this stage.
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.terminalStatusResponse.rawValue), object: message)
    }
    
    func terminalConfigurationResponse(_ message: SPIMessage!) {
        SPILogMsg("terminalStatusResponse")
        
        // Let's show the user what options he has at this stage.
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.terminalConfigurationResponse.rawValue), object: message)
    }
    
    func batteryLevelChanged(_ message: SPIMessage!) {
        SPILogMsg("batteryLevelChanged")
        
        // Let's show the user what options he has at this stage.
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppEvent.batteryLevelChanged.rawValue), object: message)
    }
}
