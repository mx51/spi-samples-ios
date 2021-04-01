//
//  TenantPickerViewController.swift
//  MotelPos
//
//  Created by mx51 on 31/3/21.
//  Copyright © 2021 mx51. All rights reserved.
//

import UIKit

class TenantPickerViewController: UIPickerView, UIPickerViewDataSource, UIPickerViewDelegate {
    var connectionViewController: ConnectionViewController?
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return MotelApp.current.settings.tenantList.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return MotelApp.current.settings.tenantList[row]["name"]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedTenantName = MotelApp.current.settings.tenantList[row]["name"]
        let isOtherTenantSelected = selectedTenantName == "Other"

        connectionViewController?.txtTenant.text = MotelApp.current.settings.tenantList[row]["name"]

        if (!isOtherTenantSelected) { connectionViewController?.txtOtherTenant.text = "" }
        connectionViewController?.txtOtherTenant.isEnabled = isOtherTenantSelected

        connectionViewController?.txtTenant.resignFirstResponder()
    }
}
