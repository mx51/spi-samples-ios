//
//  AppEvents.swift
//  TablePos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation

enum AppEvent: String {
    case connectionStatusChanged
    case pairingFlowChanged
    case transactionFlowStateChanged
    case secretsDropped
    case payAtTableGetOpenTables
    case payAtTableGetBillStatus
    case payAtTableBillPaymentReceived
    case payAtTableBillPaymentFlowEnded
}
