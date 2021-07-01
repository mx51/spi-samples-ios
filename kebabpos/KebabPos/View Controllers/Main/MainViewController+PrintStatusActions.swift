//
//  MainViewController+PrintStatusActions.swift
//  KebabPos
//
//  Created by Amir Kamali on 6/6/18.
//  Copyright © 2018 mx51. All rights reserved.
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
                switch (txState.type) {
                case .purchase:
                    handleFinishedPurchase(txState: txState)
                    break
                case .refund:
                    handleFinishedRefund(txState: txState)
                    break
                case .cashoutOnly:
                    handleFinishedCashout(txState: txState)
                    break
                case .MOTO:
                    handleFinishedMoto(txState: txState)
                    break
                case .settle:
                    HandleFinishedSettle(txState: txState)
                    break
                case .settleEnquiry:
                    handleFinishedSettlementEnquiry(txState: txState)
                    break
                case .getLastTransaction:
                    handleFinishedGetLastTransaction(txState: txState)
                    break
                case .reversal:
                    handleFinishedReversal(txState: txState)
                default:
                    logMessage(String(format: "# CAN'T HANDLE TX TYPE: {txState.Type}"))
                    break
                }
            }
        case .idle:
            break
        }
    }
    
    func handleFinishedReversal(txState: SPITransactionFlowState) {
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# NOICE - TRANSACTION REVERSED!"))
        case .failed:
            logMessage(String(format: "# WE DID NOT GET OUR MONEY BACK :("))
            logMessage(String(format: "# Error: %@", txState.response.error))
            logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
        case .unknown:
            logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER THE REVERSAL WENT THROUGH OR NOT :/"))
            logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
            logMessage(String(format: "# YOU CAN THE TAKE THE APPROPRIATE ACTION."))
            break
        }
    }
    
    func handleFinishedPurchase(txState: SPITransactionFlowState) {
        let purchaseResponse: SPIPurchaseResponse
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# WOOHOO - WE GOT PAID!"))
            purchaseResponse = SPIPurchaseResponse(message: txState.response)
            logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
            logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
            logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
            logMessage(String(format: "# Customer Receipt:"))
            logMessage((!purchaseResponse.wasCustomerReceiptPrinted()) ? purchaseResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS")
            logMessage(String(format: "# PURCHASE: %i", purchaseResponse.getPurchaseAmount()))
            logMessage(String(format: "# TIP: %i", purchaseResponse.getTipAmount()))
            logMessage(String(format: "# SURCHARGE: %i", purchaseResponse.getSurchargeAmount()))
            logMessage(String(format: "# CASHOUT: %i", purchaseResponse.getCashoutAmount()))
            logMessage(String(format: "# BANKED NON-CASH AMOUNT: %i", purchaseResponse.getBankNonCashAmount()))
            logMessage(String(format: "# BANKED CASH AMOUNT: %i", purchaseResponse.getBankCashAmount()))
        case .failed:
            logMessage(String(format: "# WE DID NOT GET PAID :("))
            logMessage(String(format: "# Error: %@", txState.response.error))
            logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
            if (txState.response != nil) {
                purchaseResponse = SPIPurchaseResponse(message: txState.response)
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Customer receipt:"))
                logMessage(!purchaseResponse.wasCustomerReceiptPrinted()
                    ? purchaseResponse.getCustomerReceipt(): "# PRINTED FROM EFTPOS")
            }
            break
        case .unknown:
            logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER WE GOT PAID OR NOT :/"))
            logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
            logMessage(String(format: "# IF YOU CONFIRM THAT THE CUSTOMER PAID, CLOSE THE ORDER."))
            logMessage(String(format: "# OTHERWISE, RETRY THE PAYMENT FROM SCRATCH."))
            break
        }
    }
    
    func handleFinishedRefund(txState: SPITransactionFlowState) {
        let refundResponse: SPIRefundResponse
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# REFUND GIVEN- OH WELL!"))
            refundResponse = SPIRefundResponse(message: txState.response)
            logMessage(String(format: "# Response: %@", refundResponse.getText()))
            logMessage(String(format: "# RRN: %@", refundResponse.getRRN()))
            logMessage(String(format: "# Scheme: %@", refundResponse.schemeName))
            logMessage(String(format: "# Customer receipt:"))
            logMessage((!refundResponse.wasCustomerReceiptPrinted()) ? refundResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS")
            logMessage(String(format: "# REFUNDED AMOUNT: %i", refundResponse.getRefundAmount()))
            break
        case .failed:
            logMessage(String(format: "# REFUND FAILED!"))
            logMessage(String(format: "# Error: %@", txState.response.error))
            logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
            if (txState.response != nil) {
                refundResponse = SPIRefundResponse(message: txState.response)
                logMessage(String(format: "# Response: %@", refundResponse.getText()))
                logMessage(String(format: "# RRN: %@", refundResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", refundResponse.schemeName))
                logMessage(String(format: "# Customer receipt:"))
                logMessage(!refundResponse.wasCustomerReceiptPrinted() ? refundResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS")
            }
            break
        case .unknown:
            logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER THE REFUND WENT THROUGH OR NOT :/"))
            logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
            logMessage(String(format: "# YOU CAN THE TAKE THE APPROPRIATE ACTION."))
            break
        }
    }
    
    func handleFinishedCashout(txState: SPITransactionFlowState) {
        var cashoutResponse: SPICashoutOnlyResponse
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# CASH-OUT SUCCESSFUL - HAND THEM THE CASH!"))
            cashoutResponse = SPICashoutOnlyResponse(message: txState.response)
            logMessage(String(format: "# Response: %@", cashoutResponse.getText()))
            logMessage(String(format: "# RRN: %@", cashoutResponse.getRRN()))
            logMessage(String(format: "# Scheme: %@", cashoutResponse.schemeName))
            logMessage(String(format: "# Customer receipt:"))
            logMessage(((!cashoutResponse.wasCustomerReceiptPrinted()) ? cashoutResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS"))
            logMessage(String(format: "# CASHOUT: %i", cashoutResponse.getCashoutAmount()))
            logMessage(String(format: "# BANKED NON-CASH AMOUNT: %i", cashoutResponse.getBankNonCashAmount()))
            logMessage(String(format: "# BANKED CASH AMOUNT: %i", cashoutResponse.getBankCashAmount()))
            break
        case .failed:
            logMessage(String(format: "# CASHOUT FAILED!"))
            if (txState.response != nil) {
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
                cashoutResponse = SPICashoutOnlyResponse(message: txState.response)
                logMessage(String(format: "# Response: %@", cashoutResponse.getText()))
                logMessage(String(format: "# RRN: %@", cashoutResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", cashoutResponse.schemeName))
                logMessage(String(format: "# Customer receipt:"))
                logMessage(cashoutResponse.getCustomerReceipt())
            }
            break
        case .unknown:
            logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER THE CASHOUT WENT THROUGH OR NOT :/"))
            logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
            logMessage(String(format: "# YOU CAN THE TAKE THE APPROPRIATE ACTION."))
            break
        }
    }
    func handleFinishedMoto(txState: SPITransactionFlowState) {
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# WOOHOO - WE GOT MOTO-PAID!"))
            if let motoResponse = SPIMotoPurchaseResponse(message: txState.response),let purchaseResponse = motoResponse.purchaseResponse {
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Card entry: %@", purchaseResponse.getCardEntry()))
                logMessage(String(format: "# Customer receipt:"))
                logMessage((!purchaseResponse.wasCustomerReceiptPrinted() ? purchaseResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS"))
                logMessage(String(format: "# PURCHASE: %.2f", purchaseResponse.getPurchaseAmount()))
                logMessage(String(format: "# SURCHARGE: %i", purchaseResponse.getSurchargeAmount()))
                logMessage(String(format: "# BANKED NON-CASH AMOUNT: %.2f", purchaseResponse.getBankNonCashAmount()))
                logMessage(String(format: "# BANKED CASH AMOUNT: %.2f", purchaseResponse.getBankCashAmount()))
            }
            break
        case .failed:
            logMessage(String(format: "# WE DID NOT GET MOTO-PAID :("))
            logMessage(String(format: "# Error: %@", txState.response.error))
            logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
            if let response = txState.response , let motoResponse = SPIMotoPurchaseResponse(message: response),let purchaseResponse = motoResponse.purchaseResponse  {
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Customer receipt:"))
                logMessage(purchaseResponse.getCustomerReceipt())
            }
            break
        case .unknown:
            logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER THE MOTO WENT THROUGH OR NOT :/"))
            logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
            logMessage(String(format: "# YOU CAN THE TAKE THE APPROPRIATE ACTION."))
            break
        }
    }
    
    func handleFinishedGetLastTransaction(txState: SPITransactionFlowState) {
        if (txState.response != nil) {
            let gltResponse = SPIGetLastTransactionResponse(message: txState.response)
            
            if (_lastCmd.count > 1) {
                // User specified that he intended to retrieve a specific tx by pos_ref_id
                // This is how you can use a handy function to match it.
                let success = client.gltMatch(gltResponse, posRefId: _lastCmd[1])
                if (success == .unknown) {
                    logMessage(String(format: "# Did not retrieve expected transaction. Here is what we got:"))
                } else {
                    logMessage(String(format: "# Tx matched expected purchase request."))
                }
            }
            
            if let purchaseResponse = SPIPurchaseResponse(message: txState.response) {
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Customer receipt:"))
                logMessage(purchaseResponse.getCustomerReceipt())
            }
        } else {
            // We did not even get a response, like in the case of a time-out.
            logMessage(String(format: "# Could not retrieve last transaction."))
        }
    }
    
    func HandleFinishedSettle(txState: SPITransactionFlowState) {
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# SETTLEMENT SUCCESSFUL!"))
            if let settleResponse = SPISettlement(message: txState.response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Merchant receipt:"))
                logMessage(String(settleResponse.getMerchantReceipt()))
                logMessage(String(format: "# Period start: %@", settleResponse.getPeriodStartTime().toString()))
                logMessage(String(format: "# Period end: %@", settleResponse.getPeriodEndTime().toString()))
                logMessage(String(format: "# Settlement time: %@", settleResponse.getTriggeredTime().toString()))
                logMessage(String(format: "# Transaction range: %@", settleResponse.getTransactionRange()))
                logMessage(String(format: "# Terminal ID: %i", settleResponse.getTerminalId()))
                logMessage(String(format: "# Total tx count: %i", settleResponse.getTotalCount()))
                logMessage(String(format: "# Total tx value: {settleResponse.getTotalValue() / 100.0}"))
                logMessage(String(format: "# By acquirer tx count: %i", settleResponse.getSettleByAcquirerCount()))
                logMessage(String(format: "# By acquirer tx value: %.2f", Float(settleResponse.getSettleByAcquirerValue()) / 100.0))
                logMessage(String(format: "# SCHEME SETTLEMENTS:"))
                
                let schemes = settleResponse.getSchemeSettlementEntries()
                for  s in schemes ?? [] {
                    logMessage(String(format: "# %@", s))
                }
            }
            break
        case .failed:
            logMessage(String(format: "# SETTLEMENT FAILED!"))
            if let response = txState.response, let settleResponse =  SPISettlement(message: response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Merchant receipt:"))
                logMessage(settleResponse.getMerchantReceipt())
            }
            break
        case .unknown:
            logMessage(String(format: "# SETTLEMENT ENQUIRY RESULT UNKNOWN!"))
            break
        }
    }
    
    func handleFinishedSettlementEnquiry(txState: SPITransactionFlowState) {
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# SETTLEMENT ENQUIRY SUCCESSFUL!"))
            if let settleResponse = SPISettlement(message: txState.response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Merchant receipt:"))
                logMessage(settleResponse.getMerchantReceipt())
                logMessage(String(format: "# Period start: %@", settleResponse.getPeriodStartTime().toString()))
                logMessage(String(format: "# Period end: %@", settleResponse.getPeriodEndTime().toString()))
                logMessage(String(format: "# Settlement time: %@", settleResponse.getTriggeredTime().toString()))
                logMessage(String(format: "# Transaction range: %@", settleResponse.getTransactionRange()))
                logMessage(String(format: "# Terminal ID: %@", settleResponse.getTerminalId()))
                logMessage(String(format: "# Total tx count: %i", settleResponse.getTotalCount()))
                logMessage(String(format: "# Total tx value: %.2f",Float(settleResponse.getTotalValue()) / 100.0))
                logMessage(String(format: "# By acquirer tx count: %i", settleResponse.getSettleByAcquirerCount()))
                logMessage(String(format: "# By acquirer tx value: %.2f", Float(settleResponse.getSettleByAcquirerValue()) / 100.0))
                logMessage(String(format: "# SCHEME SETTLEMENTS:"))
                
                let schemes = settleResponse.getSchemeSettlementEntries()
                for s in schemes ?? [] {
                    logMessage(String(format: "# %@", s))
                }
            }
            break
        case .failed:
            logMessage(String(format: "# SETTLEMENT ENQUIRY FAILED!"))
            if let response = txState.response, let settleResponse = SPISettlement(message: response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Merchant receipt:"))
                logMessage(settleResponse.getMerchantReceipt())
            }
            break
        case .unknown:
            logMessage(String(format: "# SETTLEMENT ENQUIRY RESULT UNKNOWN!"))
            break
        }
    }
}
