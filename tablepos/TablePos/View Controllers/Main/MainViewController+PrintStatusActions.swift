//
//  MainViewController+PrintStatusActions.swift
//  TablePos
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
            logMessage(String(format: "# Amount: $%.2f", Double(txState.amountCents) / 100.0))
            logMessage(String(format: "# Waiting for signature: %@", String(txState.isAwaitingSignatureCheck)))
            logMessage(String(format: "# Attempting to cancel : %@", String(txState.isAttemptingToCancel)))
            logMessage(String(format: "# Finished: %@", String(txState.isFinished)))
            logMessage(String(format: "# Success: %@", txState.successState.name))
            
            if (txState.isFinished) {
                switch (txState.successState) {
                case .success:
                    switch (txState.type) {
                    case .purchase:
                        logMessage(String(format: "# WOOHOO - WE GOT PAID!"))
                        let purchaseResponse: SPIPurchaseResponse = SPIPurchaseResponse(message: txState.response)
                        logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                        logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                        logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                        logMessage(String(format: "# Customer Receipt:"))
                        logMessage(purchaseResponse.getCustomerReceipt().trimmingCharacters(in: .whitespacesAndNewlines))
                        logMessage(String(format: "# PURCHASE: $%.2f", Double(purchaseResponse.getPurchaseAmount()) / 100.0))
                        logMessage(String(format: "# TIP: $%.2f", Double(purchaseResponse.getTipAmount()) / 100.0))
                        logMessage(String(format: "# CASHOUT: $%.2f", Double(purchaseResponse.getCashoutAmount()) / 100.0))
                        logMessage(String(format: "# BANKED NON-CASH AMOUNT: $%.2f", Double(purchaseResponse.getBankNonCashAmount()) / 100.0))
                        logMessage(String(format: "# BANKED CASH AMOUNT: $%.2f", Double(purchaseResponse.getBankCashAmount()) / 100.0))
                        break
                    case .refund:
                        logMessage(String(format: "# REFUND GIVEN - OH WELL!"))
                        let refundResponse: SPIRefundResponse = SPIRefundResponse(message: txState.response)
                        logMessage(String(format: "# Response: %@", refundResponse.getText()))
                        logMessage(String(format: "# RRN: %@", refundResponse.getRRN()))
                        logMessage(String(format: "# Scheme: %@", refundResponse.schemeName))
                        logMessage(String(format: "# Customer Receipt:"))
                        logMessage(refundResponse.getCustomerReceipt().trimmingCharacters(in: .whitespacesAndNewlines))
                        break
                    case .settle:
                        logMessage(String(format: "# SETTLEMENT SUCCESSFUL!"))
                        if txState.response != nil {
                            let settleResponse: SPISettlement = SPISettlement(message: txState.response)
                            logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                            logMessage(String(format: "# Merchant Receipt:"))
                            logMessage(settleResponse.getMerchantReceipt().trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        break
                    default:
                        logMessage(String(format: "# TABLE POS DOESN'T KNOW WHAT TO DO WITH THIS TX TYPE WHEN IT SUCCEEDS"))
                        break
                    }
                    break
                case .failed:
                    switch (txState.type) {
                    case .purchase:
                        logMessage(String(format: "# WE DID NOT GET PAID :("))
                        if txState.response != nil {
                            let purchaseResponse: SPIPurchaseResponse = SPIPurchaseResponse(message: txState.response)
                            logMessage(String(format: "# Error: %@", txState.response.error))
                            logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                            logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                            logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                            logMessage(String(format: "# Customer Receipt:"))
                            logMessage(purchaseResponse.getCustomerReceipt().trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        break
                    case .refund:
                        logMessage(String(format: "# REFUND FAILED!"))
                        if txState.response != nil {
                            let refundResponse: SPIRefundResponse = SPIRefundResponse(message: txState.response)
                            logMessage(String(format: "# Response: %@", refundResponse.getText()))
                            logMessage(String(format: "# RRN: %@", refundResponse.getRRN()))
                            logMessage(String(format: "# Scheme: %@", refundResponse.schemeName))
                            logMessage(String(format: "# Customer Receipt:"))
                            logMessage(refundResponse.getCustomerReceipt().trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        break
                    case .settle:
                        logMessage(String(format: "# SETTLEMENT FAILED!"))
                        if txState.response != nil {
                            let settleResponse: SPISettlement = SPISettlement(message: txState.response)
                            logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                            logMessage(String(format: "# Error: %@", txState.response.error))
                            logMessage(String(format: "# Merchant Receipt:"))
                            logMessage(settleResponse.getMerchantReceipt().trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        break
                    default:
                        logMessage(String(format: "# TABLE POS DOESN'T KNOW WHAT TO DO WITH THIS TX TYPE WHEN IT SUCCEEDS"))
                        break
                    }
                    break
                case .unknown:
                    switch (txState.type) {
                    case .purchase:
                        logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER WE GOT PAID OR NOT :/"))
                        logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
                        logMessage(String(format: "# IF YOU CONFIRM THAT THE CUSTOMER PAID, CLOSE THE ORDER."))
                        logMessage(String(format: "# OTHERWISE, RETRY THE PAYMENT FROM SCRATCH."))
                        break
                    case .refund:
                        logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER THE REFUND WENT THROUGH OR NOT :/"))
                        logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
                        logMessage(String(format: "# IF YOU CONFIRM THAT THE CUSTOMER PAID, CLOSE THE ORDER."))
                        logMessage(String(format: "# OTHERWISE, RETRY THE PAYMENT FROM SCRATCH."))
                        break
                    default:
                        logMessage(String(format: "# TABLE POS DOESN'T KNOW WHAT TO DO WITH THIS TX TYPE WHEN IT FAILS"))
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
