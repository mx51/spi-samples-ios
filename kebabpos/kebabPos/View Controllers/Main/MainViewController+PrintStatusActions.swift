//
//  MainViewController+PrintStatusActions.swift
//  kebabPos
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
            guard let pairingState = state.pairingFlowState else {
                return
            }
            logMessage("### PAIRING PROCESS UPDATE ###")
            logMessage(String(format: "# %@", pairingState.message))
            logMessage(String(format: "# Finished? %@", NSNumber(booleanLiteral: pairingState.isFinished)))
            logMessage(String(format: "# Successful? %@", NSNumber(booleanLiteral: pairingState.isSuccessful)))
            logMessage(String(format: "# Confirmation Code: %@", pairingState.confirmationCode))
            logMessage(String(format: "# Waiting Confirm from Eftpos? %@", NSNumber(booleanLiteral: pairingState.isAwaitingCheckFromEftpos)))
            logMessage(String(format: "# Waiting Confirm from POS? %@", NSNumber(booleanLiteral: pairingState.isAwaitingCheckFromPos)))
        case .transaction:
            guard let txState = state.txFlowState else {
                return
            }
            logMessage("### TX PROCESS UPDATE ###")
            logMessage(String(format: "# %@", txState.displayMessage))
            logMessage(String(format: "# Id: %@", txState.posRefId))
            logMessage(String(format: "# Type: %@", txState.type.name))
            logMessage(String(format: "# Amount: %.2f", Float(txState.amountCents) / 100.0))
            logMessage(String(format: "# Waiting For Signature: %@", NSNumber(booleanLiteral: txState.isAwaitingSignatureCheck)))
            logMessage(String(format: "# Attempting to Cancel : %@", NSNumber(booleanLiteral: txState.isAttemptingToCancel)))
            logMessage(String(format: "# Finished: %@", NSNumber(booleanLiteral: txState.isFinished)))
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
                default:
                    logMessage(String(format: "# CAN'T HANDLE TX TYPE: {txState.Type}"))
                    break
                }
            }
        case .idle:
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
            logMessage(String(format: "# CASHOUT: %i", purchaseResponse.getCashoutAmount()))
            logMessage(String(format: "# BANKED NON-CASH AMOUNT: %i", purchaseResponse.getBankNonCashAmount()))
            logMessage(String(format: "# BANKED CASH AMOUNT: %i", purchaseResponse.getBankCashAmount()))
        case .failed:
            logMessage(String(format: "# WE DID NOT GET PAID :("))
            logMessage(String(format: "# Error: %@", txState.response.error))
            logMessage(String(format: "# Error Detail: %@", txState.response.errorDetail))
            if (txState.response != nil) {
                purchaseResponse = SPIPurchaseResponse(message: txState.response)
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Customer Receipt:"))
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
            logMessage(String(format: "# Customer Receipt:"))
            logMessage((!refundResponse.wasCustomerReceiptPrinted()) ? refundResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS")
            logMessage(String(format: "# REFUNDED AMOUNT: %i", refundResponse.getRefundAmount()))
            break
        case .failed:
            logMessage(String(format: "# REFUND FAILED!"))
            logMessage(String(format: "# Error: %@", txState.response.error))
            logMessage(String(format: "# Error Detail: %@", txState.response.errorDetail))
            if (txState.response != nil) {
                refundResponse = SPIRefundResponse(message: txState.response)
                logMessage(String(format: "# Response: %@", refundResponse.getText()))
                logMessage(String(format: "# RRN: %@", refundResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", refundResponse.schemeName))
                logMessage(String(format: "# Customer Receipt:"))
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
            logMessage(String(format: "# Customer Receipt:"))
            logMessage(((!cashoutResponse.wasCustomerReceiptPrinted()) ? cashoutResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS"))
            logMessage(String(format: "# CASHOUT: %i", cashoutResponse.getCashoutAmount()))
            logMessage(String(format: "# BANKED NON-CASH AMOUNT: %i", cashoutResponse.getBankNonCashAmount()))
            logMessage(String(format: "# BANKED CASH AMOUNT: %i", cashoutResponse.getBankCashAmount()))
            break
        case .failed:
            logMessage(String(format: "# CASHOUT FAILED!"))
            if (txState.response != nil) {
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Error Detail: %@", txState.response.errorDetail))
                cashoutResponse = SPICashoutOnlyResponse(message: txState.response)
                logMessage(String(format: "# Response: %@", cashoutResponse.getText()))
                logMessage(String(format: "# RRN: %@", cashoutResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", cashoutResponse.schemeName))
                logMessage(String(format: "# Customer Receipt:"))
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
        var motoResponse: SPIMotoPurchaseResponse
        var purchaseResponse: SPIPurchaseResponse
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# WOOHOO - WE GOT MOTO-PAID!"))
            motoResponse = SPIMotoPurchaseResponse(message: txState.response)
            purchaseResponse = motoResponse.purchaseResponse
            logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
            logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
            logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
            logMessage(String(format: "# Card Entry: %@", purchaseResponse.getCardEntry()))
            logMessage(String(format: "# Customer Receipt:"))
            logMessage((!purchaseResponse.wasCustomerReceiptPrinted() ? purchaseResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS"))
            logMessage(String(format: "# PURCHASE: %@", purchaseResponse.getPurchaseAmount()))
            logMessage(String(format: "# BANKED NON-CASH AMOUNT: %@", purchaseResponse.getBankNonCashAmount()))
            logMessage(String(format: "# BANKED CASH AMOUNT: %@", purchaseResponse.getBankCashAmount()))
            break
        case .failed:
            logMessage(String(format: "# WE DID NOT GET MOTO-PAID :("))
            logMessage(String(format: "# Error: %@", txState.response.error))
            logMessage(String(format: "# Error Detail: %@", txState.response.errorDetail))
            if (txState.response != nil) {
                motoResponse = SPIMotoPurchaseResponse(message: txState.response)
                purchaseResponse = motoResponse.purchaseResponse
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Customer Receipt:"))
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
                    logMessage(String(format: "# Did not retrieve Expected Transaction. Here is what we got:"))
                } else {
                    logMessage(String(format: "# Tx Matched Expected Purchase Request."))
                }
            }

            if let purchaseResponse = SPIPurchaseResponse(message: txState.response) {
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Customer Receipt:"))
                logMessage(purchaseResponse.getCustomerReceipt())
            }
        } else {
            // We did not even get a response, like in the case of a time-out.
            logMessage(String(format: "# Could Not Retrieve Last Transaction."))
        }
    }

    func HandleFinishedSettle(txState: SPITransactionFlowState) {
        switch (txState.successState) {
        case .success:
            logMessage(String(format: "# SETTLEMENT SUCCESSFUL!"))
            if let settleResponse = SPISettlement(message: txState.response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Merchant Receipt:"))
                logMessage(String(settleResponse.getReceipt()))
                logMessage(String(format: "# Period Start: %@", settleResponse.getPeriodStartTime().toString()))
                logMessage(String(format: "# Period End: %@", settleResponse.getPeriodEndTime().toString()))
                logMessage(String(format: "# Settlement Time: %@", settleResponse.getTriggeredTime().toString()))
                logMessage(String(format: "# Transaction Range: %@", settleResponse.getTransactionRange()))
                logMessage(String(format: "# Terminal Id: %i", settleResponse.getTerminalId()))
                logMessage(String(format: "# Total TX Count: %i", settleResponse.getTotalCount()))
                logMessage(String(format: "# Total TX Value: {settleResponse.getTotalValue() / 100.0}"))
                logMessage(String(format: "# By Aquirer TX Count: %i", settleResponse.getSettleByAcquirerCount()))
                logMessage(String(format: "# By Aquirer TX Value: %.2f", Float(settleResponse.getSettleByAcquirerValue()) / 100.0))
                logMessage(String(format: "# SCHEME SETTLEMENTS:"))
                let schemes = settleResponse.getSchemeSettlementEntries()
                for  s in schemes ?? [] {
                    logMessage(String(format: "# %@", s))
                }

            }
            break
        case .failed:
            logMessage(String(format: "# SETTLEMENT FAILED!"))
            if let settleResponse =  SPISettlement(message: txState.response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Merchant Receipt:"))
                logMessage(settleResponse.getReceipt())
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
                logMessage(String(format: "# Merchant Receipt:"))
                logMessage(settleResponse.getReceipt())
                logMessage(String(format: "# Period Start: %@", settleResponse.getPeriodStartTime().toString()))
                logMessage(String(format: "# Period End: %@", settleResponse.getPeriodEndTime().toString()))
                logMessage(String(format: "# Settlement Time: %@", settleResponse.getTriggeredTime().toString()))
                logMessage(String(format: "# Transaction Range: %@", settleResponse.getTransactionRange()))
                logMessage(String(format: "# Terminal Id: %@", settleResponse.getTerminalId()))
                logMessage(String(format: "# Total TX Count: %@", settleResponse.getTotalCount()))
                logMessage(String(format: "# Total TX Value: {settleResponse.getTotalValue() / 100.0}"))
                logMessage(String(format: "# By Aquirer TX Count: %@", settleResponse.getSettleByAcquirerCount()))
                logMessage(String(format: "# By Aquirere TX Value: %.2f", Float(settleResponse.getSettleByAcquirerValue()) / 100.0))
                logMessage(String(format: "# SCHEME SETTLEMENTS:"))
                let schemes = settleResponse.getSchemeSettlementEntries()
                for s in schemes ?? [] {
                    logMessage(String(format: "# %@", s))
                }
            }
            break
        case .failed:
            logMessage(String(format: "# SETTLEMENT ENQUIRY FAILED!"))
            if let settleResponse = SPISettlement(message: txState.response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Merchant Receipt:"))
                logMessage(settleResponse.getReceipt())
            }
            break
        case .unknown:
            logMessage(String(format: "# SETTLEMENT ENQUIRY RESULT UNKNOWN!"))
            break
        }
    }
}
