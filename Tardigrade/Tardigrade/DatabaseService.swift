//
//  DatabaseService.swift
//  Tardigrade
//
//  Created by Matthew Lorentz on 4/21/18.
//  Copyright © 2018 Matthew Lorentz. All rights reserved.
//

import Foundation
import Reachability
import CoreBluetooth



class DatabaseService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    
    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager!
    let serviceID = CBUUID(string: "4499d2d0-26e8-4678-8b25-8fd84816eb7e")
    let characteristicID = CBUUID(string: "53dc74ee-accb-4f00-a86e-fdf15c8d2fe4")
    var peripherals = [CBPeripheral]()
    var peripheralData = [CBPeripheral: Data]()
    var centralHasHeardStartMessage = [CBPeripheral: Bool]()
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            print("BLUETOOTH DID NOT COME ON")
        }
        
        centralManager.scanForPeripherals(withServices: [serviceID], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        peripherals.append(peripheral)
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("FAILED TO CONNECT TO PERIPHERAL")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            peripheral.discoverCharacteristics([characteristicID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics! {
            if char.uuid == characteristicID {
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        let message = String(data: characteristic.value!, encoding: .utf8)!
        let hasHeardSOM = centralHasHeardStartMessage[peripheral]!
        
        if hasHeardSOM {
            var dataSoFar: Data
            if let data = peripheralData[peripheral] {
                dataSoFar = data
            } else {
                dataSoFar = Data()
            }

            if message == "EOM" {
                Database().merge(data: dataSoFar)
                return
            } else {
                // append to our data
                let newData = (String(data: dataSoFar, encoding: .utf8)! + message).data(using: .utf8)
                peripheralData[peripheral] = newData
                return
            }
        }
        
        if message == "SOM" {
            centralHasHeardStartMessage[peripheral] = true
            return
        }
    }
    
    func startSyncing() {
        startAdvertisingBluetoothService()
        startScanningForNearbyDevices()
    
        DispatchQueue.global().async {
            
        
            while true {
                if Reachability()!.connection != .none {
                    self.uploadDatabase()
                    self.downloadDatabase()
                }
                sleep(1)
            }
        }
    }
    
    func startAdvertisingBluetoothService() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanningForNearbyDevices() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    var recordData = Data()
    var dataToSend = Data()
    var characteristic: CBMutableCharacteristic!
    var service: CBMutableService!
    var sendDataIndex = 0
    var sendingEOM = false
    var hasStartedSending = true
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state != .poweredOn {
            print("PERIPHERAL MANAGER DID NOT POWER ON")
        }

        
        characteristic = CBMutableCharacteristic(type: characteristicID, properties: .notify, value: nil, permissions: .readable)
        service = CBMutableService(type: serviceID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager.add(service)
        
        sendData()
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
    
    func sendData() {
        if (sendingEOM) {
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: characteristic, onSubscribedCentrals: nil)
            
            if (didSend) {
                sendingEOM = false
                print("sent EOM")
            } else {
                return
            }
        }
        
        if hasStartedSending {
            if sendDataIndex >= recordData.count {
                sendingEOM = true
                return
            }
            
            let amountToSend = min(dataToSend.count - sendDataIndex, 20)
            
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex+amountToSend))
            
            let didSend = peripheralManager.updateValue(chunk, for: characteristic, onSubscribedCentrals: nil)
            
            if !didSend {
                return
            }
            
            sendDataIndex += amountToSend
        } else {
            Database.lock.lock()
            recordData = Database().fileData()
            Database.lock.unlock()
            
            dataToSend = recordData
            
            let didSend = peripheralManager.updateValue("SOM".data(using: .utf8)!, for: characteristic, onSubscribedCentrals: nil)
            
            if (didSend) {
                hasStartedSending = false
                print("sent SOM")
            } else {
                return
            }
        }

    }
    
    func uploadDatabase() {
    }
    
    func downloadDatabase() {
    }
}
