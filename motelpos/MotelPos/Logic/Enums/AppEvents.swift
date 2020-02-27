//
//  AppEvents.swift
//  MotelPos
//
//  Created by Amir Kamali on 28/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation

enum AppEvent: String {
    case connectionStatusChanged
    case pairingFlowChanged
    case transactionFlowStateChanged
    case secretsDropped
}
