//
//  AppDelegate.swift
//  TablePos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        TableApp.current.initialize()
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        TableApp.current.persistState()
    }
    
}
