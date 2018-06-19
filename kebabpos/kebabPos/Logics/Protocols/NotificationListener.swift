//
//  NotificationListener.swift
//  kebabPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation

@objc
protocol NotificationListener {
    @objc func onNotificationArrived(notification: NSNotification)
}
extension NotificationListener {
    func registerForEvents(appEvents: [AppEvent]) {
        for event in appEvents {
            NotificationCenter.default.addObserver(self, selector: #selector(onNotificationArrived), name: NSNotification.Name(rawValue: event.rawValue), object: nil)
        }
    }
}
