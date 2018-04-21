  //
//  FirstViewController.swift
//  Tardigrade
//
//  Created by Matthew Lorentz on 4/21/18.
//  Copyright © 2018 Matthew Lorentz. All rights reserved.
//

import UIKit



class FirstViewController: UIViewController {
    
    @IBOutlet var shelterSwitch: UISwitch!
    @IBOutlet var waterSwitch: UISwitch!
    @IBOutlet var peopleCount: UITextField!
    @IBOutlet var notesField: UITextView!
    @IBOutlet var firstNameField: UITextField!
    @IBOutlet var middleNameField: UITextField!
    @IBOutlet var lastNameField: UITextField!
    @IBOutlet var dobPicker: UIDatePicker!
    
    @IBAction func checkInButtonTapped(_ sender: Any) {
        let database = Database()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd"
        let dobString = dateFormatter.string(from: dobPicker.date)
        let hashString = "\(firstNameField.text!) \(middleNameField.text!) \(lastNameField.text!) \(dobString)"
        let record = Record(
            hash: hashString.sha256(),
            timestamp: Int(Date().timeIntervalSince1970),
            latitude: 0,
            longitude: 0, // TODO: populate logitude and latitude
            medicalNeed: 0,
            shelter: shelterSwitch.isOn,
            water: waterSwitch.isOn,
            peopleCount: Int(peopleCount.text!)!,
            notes: notesField.text,
            hopCount: 0
        )
        
        database.add(record: record)
    }
}

extension String {
    
    func sha256() -> String{
        if let stringData = self.data(using: String.Encoding.utf8) {
            return hexStringFromData(input: digest(input: stringData as NSData))
        }
        return ""
    }
    
    private func digest(input : NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }
    
    private  func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)
        
        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }
        
        return hexString
    }
    
}

