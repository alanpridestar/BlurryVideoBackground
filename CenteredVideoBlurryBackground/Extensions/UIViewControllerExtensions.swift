//
//  UIViewControllerExtensions.swift
//  VideoBorders
//
//  Created by macmini7 on 7/24/19.
//  Copyright © 2019 macmini7. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
	func createAlert(title: String, message: String) {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let okayAction = UIAlertAction(title: "Okay", style: .default) { (action) in
			alertController.dismiss(animated: true)
		}
		alertController.addAction(okayAction)
		present(alertController, animated: true)
	}
}
