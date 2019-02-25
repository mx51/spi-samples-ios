//
//  Bill.swift
//  TablePos
//
//  Created by Metin Avci on 14/8/18.
//  Copyright © 2018 Assembly Payments. All rights reserved.
//

import Foundation

class Bill: NSObject, NSCoding {
    var billId: String?
    var tableId: String?
    var operatorId: String?
    var label: String?
    var totalAmount: Int?
    var outstandingAmount:Int?
    var tippedAmount:Int?
    var locked:Bool?
    
    func encode(with aCoder: NSCoder) {
        if billId != nil {  aCoder.encode(billId, forKey: "billId")}
        if tableId != nil { aCoder.encode(tableId, forKey: "tableId")}
        if operatorId != nil { aCoder.encode(operatorId, forKey: "operatorId")}
        if label != nil { aCoder.encode(label, forKey: "label")}
        if totalAmount != nil { aCoder.encode(totalAmount, forKey: "totalAmount")} else { totalAmount = 0 }
        if outstandingAmount != nil { aCoder.encode(outstandingAmount, forKey: "outstandingAmount")} else { outstandingAmount = 0 }
        if tippedAmount != nil {aCoder.encode(tippedAmount, forKey: "tippedAmount")} else { tippedAmount = 0 }
        if locked != nil {aCoder.encode(locked, forKey: "locked")} else { locked = false }
    }
    
    required init(coder aDecoder: NSCoder) {
        self.billId = aDecoder.decodeObject(forKey: "billId") as? String
        self.tableId = aDecoder.decodeObject(forKey: "tableId") as? String
        self.operatorId = aDecoder.decodeObject(forKey: "operatorId") as? String
        self.label = aDecoder.decodeObject(forKey: "label") as? String
        self.totalAmount = aDecoder.decodeObject(forKey: "totalAmount") as? Int
        self.outstandingAmount = aDecoder.decodeObject(forKey: "outstandingAmount") as? Int
        self.tippedAmount = aDecoder.decodeObject(forKey: "tippedAmount") as? Int
        self.locked = aDecoder.decodeObject(forKey: "locked") as? Bool
    }
    
    override init() {
        billId = ""
        tableId = ""
        operatorId = ""
        label = ""
        totalAmount = 0
        outstandingAmount = 0
        tippedAmount = 0
        locked = false
    }
    
    func toString() -> String {
        return String(format: "%@ - Table:%@ OperatorId:%@ Label:%@ Total:$%.2f Outstanding:$%.2f Tips:$%.2f Locked:%@", billId!, tableId!, operatorId!, label!, Float(totalAmount!) / 100.0, Float(outstandingAmount!) / 100.0, Float(tippedAmount!) / 100.0, locked!.description)
    }
}
