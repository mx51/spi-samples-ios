//
//  UIViewController+Alert.swift
//  MotelPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import UIKit

var remainingAlerts:[UIAlertController] = []

extension UIViewController {
    
    func showAlert(title: String, message: String) {
        let alertController  = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        showAlert(alertController: alertController)
    }
    
    func showAlert(alertController: UIAlertController) {
        func displayNext(){
            if remainingAlerts.count > 0 {
                let nextAlert = remainingAlerts.remove(at: 0)
                self.showAlert(alertController: nextAlert)
            }
        }
        
        func display() {
            DispatchQueue.main.async {
                self.present(alertController, animated: true) {
                    displayNext()
                }
            }
        }
        
        if (presentedViewController == nil) {
            display()
        } else if let existingAlert = presentedViewController as? UIAlertController {
            if (!existingAlert.isBeingDismissed && !existingAlert.isBeingPresented){
                existingAlert.dismiss(animated: false, completion: {
                    display()
                })
            } else {
                addToRemaining(alert: alertController)
            }
            return
        }
    }
    
    // In case multiple alerts needs to be shown in a sequence, we keep them in an array to display later
    private func addToRemaining(alert:UIAlertController){
        if let existingAlert = presentedViewController as? UIAlertController , existingAlert.message == alert.message {
            return
        }
        else if remainingAlerts.isEmpty{
            remainingAlerts.append(alert)
        } else if let lastAlert = remainingAlerts.last, lastAlert.message != alert.message {
            //if not duplicated messages
            remainingAlerts.append(alert)
        }
    }
    
}
