//
//  SPIExtensions.swift
//  kebabPos
//
//  Created by Amir Kamali on 6/6/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import SPIClient_iOS

extension SPIMessageSuccessState {
    var name: String {
        switch self {
        case .failed:
            return "failed"
        case .success:
            return "success"
        case .unknown:
            return "unknown"
        }
    }
}
extension SPIFlow {
    var name: String {
        switch self {
        case .idle:
            return "Idle"
        case .pairing:
            return "Pairing"
        case .transaction:
            return "Transaction"
        }
    }
}
extension SPITransactionType {
    var name: String {
        switch self {
        case .getLastTransaction:
            return "Get Last Transaction"
        case .purchase:
            return "Purchase"
        case .refund:
            return "Refund"
        case .settle:
            return "Settle"
        case .cashoutOnly:
            return "Cashout Only"
        case .MOTO:
            return "MOTO"
        case .settleEnquiry:
            return "Settle Enquiry"
        case .preAuth:
            return "Pre Auth"
        case .accountVerify:
            return "Account Verify"
        }
    }
}
