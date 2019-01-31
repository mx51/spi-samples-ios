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
    var totalAmount: Int?
    var outstandingAmount:Int?
    var tippedAmount:Int?
    
    func encode(with aCoder: NSCoder) {
        if billId != nil {  aCoder.encode(billId, forKey: "billId")}
        if tableId != nil { aCoder.encode(tableId, forKey: "tableId")}
        if totalAmount != nil { aCoder.encode(totalAmount, forKey: "totalAmount")} else { totalAmount = 0 }
        if outstandingAmount != nil { aCoder.encode(outstandingAmount, forKey: "outstandingAmount")} else { outstandingAmount = 0 }
        if tippedAmount != nil {aCoder.encode(tippedAmount, forKey: "tippedAmount")} else { tippedAmount = 0 }
    }
    
    required init(coder aDecoder: NSCoder) {
        self.billId = aDecoder.decodeObject(forKey: "billId") as? String
        self.tableId = aDecoder.decodeObject(forKey: "tableId") as? String
        self.totalAmount = aDecoder.decodeObject(forKey: "totalAmount") as? Int
        self.outstandingAmount = aDecoder.decodeObject(forKey: "outstandingAmount") as? Int
        self.tippedAmount = aDecoder.decodeObject(forKey: "tippedAmount") as? Int
    }

    override init() {
        billId = ""
        tableId = ""
        totalAmount = 0
        outstandingAmount = 0
        tippedAmount = 0
    }
    
    func toString() -> String {
        return String(format: "%@ - Table:%@ Total:$%.2f Outstanding:$%.2f Tips:$%.2f", billId!, tableId!, Float(totalAmount!) / 100.0, Float(outstandingAmount!) / 100.0, Float(tippedAmount!) / 100.0)
    }
}
