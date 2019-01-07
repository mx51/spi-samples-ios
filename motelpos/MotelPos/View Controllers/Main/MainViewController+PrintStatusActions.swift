//
//  MainViewController+PrintStatusActions.swift
//  MotelPos
//
//  Created by Amir Kamali on 6/6/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension MainViewController {
    
    func logMessage(_ message: String) {
        txtOutput.text = message + "\r\n" + txtOutput.text
        print(message)
    }
    
    func printFlowInfo(state: SPIState) {
        switch state.flow {
        case .pairing:
            guard let pairingState = state.pairingFlowState else { return }
            
            logMessage("### PAIRING PROCESS UPDATE ###")
            logMessage(String(format: "# %@", pairingState.message))
            logMessage(String(format: "# Finished? %@", String(pairingState.isFinished)))
            logMessage(String(format: "# Successful? %@", String(pairingState.isSuccessful)))
            logMessage(String(format: "# Confirmation code: %@", pairingState.confirmationCode))
            logMessage(String(format: "# Waiting confirm from EFTPOS? %@", String(pairingState.isAwaitingCheckFromEftpos)))
            logMessage(String(format: "# Waiting confirm from POS? %@", String(pairingState.isAwaitingCheckFromPos)))
            break
        case .transaction:
            guard let txState = state.txFlowState else { return }
            
            logMessage("### TX PROCESS UPDATE ###")
            logMessage(String(format: "# %@", txState.displayMessage))
            logMessage(String(format: "# ID: %@", txState.posRefId))
            logMessage(String(format: "# Type: %@", txState.type.name))
            logMessage(String(format: "# Amount: %.2f", Float(txState.amountCents) / 100.0))
            logMessage(String(format: "# Waiting for signature: %@", String(txState.isAwaitingSignatureCheck)))
            logMessage(String(format: "# Attempting to cancel : %@", String(txState.isAttemptingToCancel)))
            logMessage(String(format: "# Finished: %@", String(txState.isFinished)))
            logMessage(String(format: "# Success: %@", txState.successState.name))
            
            if (txState.isAwaitingSignatureCheck) {
                // We need to print the receipt for the customer to sign.
                logMessage(String(format: "# RECEIPT TO PRINT FOR SIGNATURE"))
                logMessage(txState.signatureRequiredMessage.getMerchantReceipt())
            }
            
            if (txState.isAwaitingPhoneForAuth) {
                logMessage(String(format: "# PHONE FOR AUTH DETAILS:"))
                logMessage(String(format: "# CALL: {txState.PhoneForAuthRequiredMessage.getPhoneNumber()}"))
                logMessage(String(format: "# QUOTE: Merchant Id: {txState.PhoneForAuthRequiredMessage.getMerchantId()}"))
            }
            
            if (txState.isFinished) {
                switch (txState.successState) {
                case .success:
                    switch (txState.type) {
                    case .preAuth:
                        logMessage(String(format: "# PREAUTH RESULT - SUCCESS"))
                        let preauthResponse: SPIPreauthResponse = SPIPreauthResponse(message: txState.response)
                        
                        if let preauthId = preauthResponse.preauthId {
                            logMessage(String(format: "# PREAUTH-ID: %i", preauthId))
                        }
                        
                        logMessage(String(format: "# NEW BALANCE AMOUNT: $%.2f", Float(preauthResponse.getBalanceAmount()) / 100.0))
                        logMessage(String(format: "# PREV BALANCE AMOUNT: $%.2f", Float(preauthResponse.getPreviousBalanceAmount()) / 100.0))
                        logMessage(String(format: "# COMPLETION AMOUNT: $%.2f", Float(preauthResponse.getCompletionAmount()) / 100.0))
                        logMessage(String(format: "# SURCHARGE AMOUNT: $%.2f", Float(preauthResponse.getSurchargeAmountForPreauthCompletion()) / 100.0))
                        
                        let details: SPIPurchaseResponse = preauthResponse.details
                        logMessage(String(format: "# Response: %@", details.getText()))
                        logMessage(String(format: "# RRN: %@", details.getRRN()))
                        logMessage(String(format: "# Scheme: %@", details.schemeName))
                        logMessage(String(format: "# Customer Receipt:"))
                        logMessage((!details.wasCustomerReceiptPrinted()) ? details.getCustomerReceipt() : "# PRINTED FROM EFTPOS")
                        break
                    case .accountVerify:
                        logMessage(String(format: "# ACCOUNT VERIFICATION SUCCESS"))
                        let acctVerifyResponse: SPIAccountVerifyResponse = SPIAccountVerifyResponse(message: txState.response)
                        
                        let details: SPIPurchaseResponse = acctVerifyResponse.details
                        logMessage(String(format: "# Response: %@", details.getText()))
                        logMessage(String(format: "# RRN: %@", details.getRRN()))
                        logMessage(String(format: "# Scheme: %@", details.schemeName))
                        logMessage(String(format: "# Customer Receipt:"))
                        logMessage((!details.wasCustomerReceiptPrinted()) ? details.getMerchantReceipt() : "# PRINTED FROM EFTPOS")
                        break
                    default:
                        logMessage(String(format: "# MOTEL POS DOESN'T KNOW WHAT TO DO WITH THIS TX TYPE WHEN IT SUCCEEDS"))
                        break
                    }
                    break
                case .failed:
                    switch (txState.type) {
                    case .preAuth:
                        logMessage(String(format: "# PREAUTH TRANSACTION FAILED :("))
                        if let response = txState.response , let purchaseResponse = SPIPurchaseResponse(message: response) {
                            logMessage(String(format: "# Error: %@", txState.response.error))
                            logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
                            logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                            logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                            logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                            logMessage(String(format: "# Customer receipt:"))
                            logMessage(purchaseResponse.getCustomerReceipt())
                        }
                        break
                    case .accountVerify:
                        logMessage(String(format: "# ACCOUNT VERIFICATION FAILED :("))
                        
                        if let response = txState.response , let acctVerifyResponse = SPIAccountVerifyResponse(message: response), let details: SPIPurchaseResponse = acctVerifyResponse.details {
                            logMessage(String(format: "# Error: %@", txState.response.error))
                            logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
                            logMessage((!details.wasCustomerReceiptPrinted()) ? details.getCustomerReceipt() : "# PRINTED FROM EFTPOS")
                        }
                        break
                    default:
                        logMessage(String(format: "# MOTEL POS DOESN'T KNOW WHAT TO DO WITH THIS TX TYPE WHEN IT FAILS"))
                        break
                    }
                    break
                case .unknown:
                    switch (txState.type) {
                    case .preAuth:
                        logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER PREAUTH TRANSACTION WENT THROUGH OR NOT :/"))
                        logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
                        logMessage(String(format: "# IF YOU CONFIRM THAT THE CUSTOMER PAID, CLOSE THE ORDER."))
                        logMessage(String(format: "# OTHERWISE, RETRY THE PAYMENT FROM SCRATCH."))
                        break
                    case .accountVerify:
                        logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER ACCOUNT VERIFICATION WENT THROUGH OR NOT :/"))
                        logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
                        logMessage(String(format: "# IF YOU CONFIRM THAT THE CUSTOMER PAID, CLOSE THE ORDER."))
                        logMessage(String(format: "# OTHERWISE, RETRY THE PAYMENT FROM SCRATCH."))
                        break
                    default:
                        logMessage(String(format: "# MOTEL POS DOESN'T KNOW WHAT TO DO WITH THIS TX TYPE WHEN IT FAILS"))
                        break
                    }
                    break
                }
                break
            }
            break
        default:
            break
        }
        logMessage(String(format: ""))
    }
    
}
