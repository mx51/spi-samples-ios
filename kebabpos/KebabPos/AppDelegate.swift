//
//  AppDelegate.swift
//  KebabPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 mx51. All rights reserved.
//

import UIKit
import SPIClient_iOS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, SPILogDelegate {

    var window: UIWindow?
    
    private var lastLogMessage: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        KebabApp.current.initialize()
        
        // Observe SPI logs from the library
        SPILogger.sharedInstance().delegate = self
        
        return true
    }

    func log(_ message: String!) {
        lastLogMessage = message
    }
    
}
