//
//  AlertViewController.swift
//  AcmePos
//
//  Created by Yoo-Jin Lee on 2018-01-24.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation
import PMAlertController
import SPIClient_iOS

// MARK: - PMAlertController Helpers

extension PMAlertController {
	func clear() {
		title = ""
		alertDescription.text = ""
		alertImage = nil
		for b in alertActionStackView.subviews {
			b.removeFromSuperview()
		}
	}
}

extension UIViewController {

	/// Returns existing presented PMAlertController or else a new PMAlertController
	///
	/// - Parameter handler: PMAlertController
	func alert(_ title: String = "", message: String = "", handler: ((PMAlertController) -> ())?) {
		SPILogMsg("alert: \(title), \(message)")

		dispatch() { [weak self] in
			guard let `self` = self else { return }

			var needsToPresent: Bool
			var alertVC: PMAlertController

			if let presentedViewController = self.presentedViewController as? PMAlertController {
				presentedViewController.clear()
				presentedViewController.alertTitle.text = title
				presentedViewController.alertDescription.text = message
				needsToPresent = false
				alertVC = presentedViewController

			} else {
				needsToPresent = true
				alertVC = PMAlertController(title: title, description: message, image: nil, style: .alert)
			}

            if let handler = handler {
                handler(alertVC)
            }
            
			if (needsToPresent) {
				self.present(alertVC, animated: true, completion: nil)
			}
		}
	}
}
