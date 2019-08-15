//
//  MainViewController+PrintStatusActions.swift
//  RamenPos
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
                default:
                    logMessage(String(format: "# CAN'T HANDLE TX TYPE: {txState.Type}"))
                    break
                }
            }
        case .idle:
            break
        default:
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
            logMessage(String(format: "# PURCHASE: %.2f", Float(purchaseResponse.getPurchaseAmount()) / 100.0))
            logMessage(String(format: "# TIP: %.2f", Float(purchaseResponse.getTipAmount()) / 100.0))
            logMessage(String(format: "# SURCHARGE: %.2f", Float(purchaseResponse.getSurchargeAmount()) / 100.0))
            logMessage(String(format: "# CASHOUT: %.2f", Float(purchaseResponse.getCashoutAmount()) / 100.0))
            logMessage(String(format: "# BANKED NON-CASH AMOUNT: %.2f", Float(purchaseResponse.getBankNonCashAmount()) / 100.0))
            logMessage(String(format: "# BANKED CASH AMOUNT: %.2f", Float(purchaseResponse.getBankCashAmount()) / 100.0))
        case .failed:
            logMessage(String(format: "# WE DID NOT GET PAID :("))
            if (txState.response != nil) {
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
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
        default:
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
            logMessage(String(format: "# REFUNDED AMOUNT: %.2f", Float(refundResponse.getRefundAmount()) / 100.0))
            break
        case .failed:
            logMessage(String(format: "# REFUND FAILED!"))
            if (txState.response != nil) {
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
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
        default:
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
            logMessage(String(format: "# CASHOUT: %.2f", Float(cashoutResponse.getCashoutAmount()) / 100.0))
            logMessage(String(format: "# BANKED NON-CASH AMOUNT: %.2f", Float(cashoutResponse.getBankNonCashAmount()) / 100.0))
            logMessage(String(format: "# BANKED CASH AMOUNT: %.2f", Float(cashoutResponse.getBankCashAmount()) / 100.0))
            logMessage(String(format: "# SURCHARGE: %.2f", Float(cashoutResponse.getSurchargeAmount()) / 100.0))
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
        default:
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
                logMessage(String(format: "# PURCHASE: %.2f", Float(purchaseResponse.getPurchaseAmount()) / 100.0))
                logMessage(String(format: "# SURCHARGE: %.2f", Float(purchaseResponse.getSurchargeAmount()) / 100.0))
                logMessage(String(format: "# BANKED NON-CASH AMOUNT: %.2f", Float(purchaseResponse.getBankNonCashAmount()) / 100.0))
                logMessage(String(format: "# BANKED CASH AMOUNT: %.2f", Float(purchaseResponse.getBankCashAmount()) / 100.0))
            }
            break
        case .failed:
            logMessage(String(format: "# WE DID NOT GET MOTO-PAID :("))
            if let response = txState.response , let motoResponse = SPIMotoPurchaseResponse(message: response),let purchaseResponse = motoResponse.purchaseResponse  {
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Error detail: %@", txState.response.errorDetail))
                logMessage(String(format: "# Response: %@", purchaseResponse.getText()))
                logMessage(String(format: "# RRN: %@", purchaseResponse.getRRN()))
                logMessage(String(format: "# Scheme: %@", purchaseResponse.schemeName))
                logMessage(String(format: "# Customer receipt:"))
                logMessage((!purchaseResponse.wasCustomerReceiptPrinted() ? purchaseResponse.getCustomerReceipt() : "# PRINTED FROM EFTPOS"))
            }
            break
        case .unknown:
            logMessage(String(format: "# WE'RE NOT QUITE SURE WHETHER THE MOTO WENT THROUGH OR NOT :/"))
            logMessage(String(format: "# CHECK THE LAST TRANSACTION ON THE EFTPOS ITSELF FROM THE APPROPRIATE MENU ITEM."))
            logMessage(String(format: "# YOU CAN THE TAKE THE APPROPRIATE ACTION."))
            break
        default:
            break
        }
    }
    
    func handleFinishedGetLastTransaction(txState: SPITransactionFlowState) {
        if (txState.response != nil) {
            let gltResponse = SPIGetLastTransactionResponse(message: txState.response)
            
            if (txtReferenceId.text != "") {
                // User specified that he intended to retrieve a specific tx by pos_ref_id
                // This is how you can use a handy function to match it.
                let success = client.gltMatch(gltResponse, posRefId: txtReferenceId.text)
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
                logMessage((!settleResponse.wasMerchantReceiptPrinted() ? settleResponse.getMerchantReceipt() : "# PRINTED FROM EFTPOS"))
                logMessage(String(format: "# Period start: %@", settleResponse.getPeriodStartTime().toString()))
                logMessage(String(format: "# Period end: %@", settleResponse.getPeriodEndTime().toString()))
                logMessage(String(format: "# Settlement time: %@", settleResponse.getTriggeredTime().toString()))
                logMessage(String(format: "# Transaction range: %@", settleResponse.getTransactionRange()))
                logMessage(String(format: "# Terminal ID: %i", settleResponse.getTerminalId()))
                logMessage(String(format: "# Total tx count: %i", settleResponse.getTotalCount()))
                logMessage(String(format: "# Total tx value: %.2f", Float(settleResponse.getTotalValue()) / 100.0))
                logMessage(String(format: "# By acquirer tx count: %i", settleResponse.getSettleByAcquirerCount()))
                logMessage(String(format: "# By acquirer tx value: %.2f", Float(settleResponse.getSettleByAcquirerValue()) / 100.0))
                logMessage(String(format: "# SCHEME SETTLEMENTS:"))
                
                let schemes = settleResponse.getSchemeSettlementEntries()
                for  s in schemes ?? [] {
                    logMessage(String(format: "Scheme Name: %@, SettleByAcquirer: %@, TotalCount: %i, TotalValue: %.2f", s.schemeName, String(s.settleByAcquirer), s.totalCount, Float(s.totalValue) / 100.0))
                }
                
                
            }
            break
        case .failed:
            logMessage(String(format: "# SETTLEMENT FAILED!"))
            if let response = txState.response, let settleResponse =  SPISettlement(message: response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Merchant receipt:"))
                logMessage((!settleResponse.wasMerchantReceiptPrinted() ? settleResponse.getMerchantReceipt() : "# PRINTED FROM EFTPOS"))
            }
            break
        case .unknown:
            logMessage(String(format: "# SETTLEMENT ENQUIRY RESULT UNKNOWN!"))
            break
        default:
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
                logMessage((!settleResponse.wasMerchantReceiptPrinted() ? settleResponse.getMerchantReceipt() : "# PRINTED FROM EFTPOS"))
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
                    logMessage(String(format: "Scheme Name: %@, SettleByAcquirer: %@, TotalCount: %i, TotalValue: %.2f", s.schemeName, String(s.settleByAcquirer), s.totalCount, Float(s.totalValue) / 100.0))
                }
            }
            break
        case .failed:
            logMessage(String(format: "# SETTLEMENT ENQUIRY FAILED!"))
            if let response = txState.response, let settleResponse = SPISettlement(message: response) {
                logMessage(String(format: "# Response: %@", settleResponse.getResponseText()))
                logMessage(String(format: "# Error: %@", txState.response.error))
                logMessage(String(format: "# Merchant receipt:"))
                logMessage((!settleResponse.wasMerchantReceiptPrinted() ? settleResponse.getMerchantReceipt() : "# PRINTED FROM EFTPOS"))
            }
            break
        case .unknown:
            logMessage(String(format: "# SETTLEMENT ENQUIRY RESULT UNKNOWN!"))
            break
        default:
            break
        }
    }
    
    func handlePrintingResponse(message: SPIMessage) {
        let printingResponse: SPIPrintingResponse = SPIPrintingResponse(message: message)
        if (printingResponse.isSuccess) {
            showMessage(title: "Print Receipt", msg: "Printing Receipt successful", type: "INFO", isShow: true)
            return
        } else {
            showMessage(title: "Print Receipt", msg: "ERROR: Printing Receipt failed: reason=\(String(describing: printingResponse.getErrorReason())), detail=\(String(describing: printingResponse.getErrorDetail()))", type: "ERROR", isShow: true)
        }
    }
    
    func handleTerminalStatusResponse(message: SPIMessage) {
        let terminalStatusResponse: SPITerminalStatusResponse = SPITerminalStatusResponse(message: message)
        if (terminalStatusResponse.isSuccess) {
            lblCharging.text = terminalStatusResponse.getCharging().toString()
            lblTerminalStatus.text = terminalStatusResponse.getStatus()
            
            let batterLevel: String = terminalStatusResponse.getBatteryLevel().replacingOccurrences(of: "d", with: "");
            lblBatteryLevel.text = batterLevel + "%";
            
            if Int(batterLevel)! >= 50 {
                lblBatteryLevel.textColor = UIColor.green
            } else {
                lblBatteryLevel.textColor = UIColor.red
            }
            
            showMessage(title: "Terminal Status", msg: "Terminal Status retrieving successful", type: "INFO", isShow: true)
            return
        } else {
            showMessage(title: "Terminal Status", msg: "ERROR: Terminal Status retrieving failed", type: "ERROR", isShow: true)
        }
    }
    
    func handleTerminalConfigurationResponse(message: SPIMessage) {
        let terminalConfigResponse: SPITerminalConfigurationResponse = SPITerminalConfigurationResponse(message: message)
        if (terminalConfigResponse.isSuccess) {
            lblCommsSelected.text = terminalConfigResponse.getCommsSelected()
            lblMerchantId.text = terminalConfigResponse.getMerchantId()
            lblPAVersion.text = terminalConfigResponse.getPAVersion()
            lblPaymentInterfaceVersion.text = terminalConfigResponse.getPaymentInterfaceVersion()
            lblPluginVersion.text = terminalConfigResponse.getPluginVersion()
            lblSerialNumber.text = terminalConfigResponse.getSerialNumber()
            lblTerminalId.text = terminalConfigResponse.getTerminalId()
            lblTerminalModel.text = terminalConfigResponse.getTerminalModel()
            
            showMessage(title: "Terminal Configuration", msg: "Terminal Configuration retrieving successful", type: "INFO", isShow: true)
            return
        } else {
            showMessage(title: "Terminal Configuration", msg: "ERROR: Terminal Configuration retrieving failed", type: "ERROR", isShow: true)
        }
    }
    
    func handleBatteryLevelChanged(message: SPIMessage) {
        let terminalBatteryResponse: SPITerminalBattery = SPITerminalBattery(message: message)
        lblBatteryLevel.text = terminalBatteryResponse.batteryLevel + "%"
        if Int(terminalBatteryResponse.batteryLevel)! >= 50 {
            lblBatteryLevel.textColor = UIColor.green
        } else {
            lblBatteryLevel.textColor = UIColor.red
        }
    }
}
