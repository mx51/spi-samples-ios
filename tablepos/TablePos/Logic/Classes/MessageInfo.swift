//
//  Message.swift
//  TablePos
//
//  Created by Metin Avci on 21/2/19.
//  Copyright © 2019 Assembly Payments. All rights reserved.
//

import Foundation

class MessageInfo {
    var title: String?
    var type: String?
    var message: String?
    var isShow = false
    
    init(title: String?, type: String?, message: String?, isShow: Bool) {
        self.title = title
        self.type = type
        self.message = message
        self.isShow = isShow
    }
    
}
