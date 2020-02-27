//
//  Thread.swift
//  AcmePos
//
//  Created by Yoo-Jin Lee on 2018-01-24.
//  Copyright © 2018 mx51. All rights reserved.
//

import Foundation

func dispatch(_ completionHandler: @escaping(() -> Swift.Void)) {

	guard !Thread.isMainThread else {
		completionHandler()
		return
	}

	DispatchQueue.main.async {
		completionHandler()
	}
}
