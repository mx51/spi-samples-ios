//
//  UIViewController+Alert.swift
//  kebabPos
//
//  Created by Amir Kamali on 29/5/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    func showAlert(title: String, message: String) {
        func display() {
            let alertController  = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }

        if (self.presentingViewController != nil) {
            self.presentedViewController?.dismiss(animated: false, completion: {
                display()
            })
        } else {
                display()
        }
    }
    func showAlert(alertController: UIAlertController) {
        func display() {
            self.present(alertController, animated: true, completion: nil)
        }
        if (self.presentedViewController != nil) {
            self.presentedViewController?.dismiss(animated: false, completion: {
                display()
            })
        } else {
            display()
        }
    }

}
