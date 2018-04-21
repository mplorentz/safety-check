//
//  Database.swift
//  Tardigrade
//
//  Created by Matthew Lorentz on 4/21/18.
//  Copyright © 2018 Matthew Lorentz. All rights reserved.
//

import Foundation
import CSV

struct Record {
    let hash: String
    let timestamp: Int
    let latitude: Double
    let longitude: Double
    let medicalNeed: Int
    let shelter: Bool
    let water: Bool
    let peopleCount: Int
    let notes: String
    let hopCount: Int
}


class Database {
    static let lock = NSLock()

    func add(record: Record) {
        DispatchQueue.global(qos: .background).async {
            Database.lock.lock()
            defer { Database.lock.unlock() }
            
            var data = self.records()
            data.append(record)
            
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
            let url = NSURL(fileURLWithPath: path)
            let pathComponent = url.appendingPathComponent("database.csv")!
            let filePath = pathComponent.path
            let stream = OutputStream(toFileAtPath: filePath, append: false)!
            
            let csv = try! CSVWriter(stream: stream)
            
            for record in data {
                let row: [String] = [
                    record.hash,
                    String(record.timestamp),
                    String(record.latitude),
                    String(record.longitude),
                    String(record.medicalNeed),
                    String(record.shelter),
                    String(record.water),
                    String(record.peopleCount),
                    record.notes,
                    String(record.hopCount + 1)
                ]
                try! csv.write(row: row)
            }
            
            csv.stream.close()
            
        }
    }
    
    // lock before calling this
    func records() -> [Record] {
        
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        let pathComponent = url.appendingPathComponent("database.csv")!
        let filePath = pathComponent.path

        var stream = InputStream(fileAtPath: filePath)!
        
        guard Data(reading: stream).count > 0 else {
            return []
        }
        stream = InputStream(fileAtPath: filePath)!
        
        let csv = try! CSVReader(stream: stream)
        var records = [Record]()
        while let row = csv.next() {
            records.append(
                Record(
                    hash: row[0],
                    timestamp: Int(row[1])!,
                    latitude: Double(row[2])!,
                    longitude: Double(row[3])!,
                    medicalNeed: Int(row[4])!,
                    shelter: Bool(row[5])!,
                    water: Bool(row[6])!,
                    peopleCount: Int(row[7])!,
                    notes: row[8],
                    hopCount: Int(row[9])!
            ))
        }
        return records
    }
    
    func merge(data: Data) {
        Database.lock.lock()
        defer { Database.lock.unlock() }
        
        var ourRecords = self.records()
        
        let reader = try! CSVReader(string: String(data: data, encoding: .utf8)!)
        var theirRecords = [Record]()
        while let row = reader.next() {
            theirRecords.append(
                Record(
                    hash: row[0],
                    timestamp: Int(row[1])!,
                    latitude: Double(row[2])!,
                    longitude: Double(row[3])!,
                    medicalNeed: Int(row[4])!,
                    shelter: Bool(row[5])!,
                    water: Bool(row[6])!,
                    peopleCount: Int(row[7])!,
                    notes: row[8],
                    hopCount: Int(row[9])!
            ))
        }
            
        var allRecords = [Record]()
        for theirRecord in theirRecords {
            let match = ourRecords.filter({ (ourRecord) -> Bool in return ourRecord.hash == theirRecord.hash}).first
            
            if let match = match {
                if match.timestamp > theirRecord.timestamp {
                    allRecords.append(match)
                    ourRecords = ourRecords.filter({ (ourRecord) -> Bool in return ourRecord.hash != theirRecord.hash})
                } else {
                    continue
                }
            } else {
                allRecords.append(theirRecord)
            }
        }
        
        allRecords.append(contentsOf: ourRecords)
        
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        let pathComponent = url.appendingPathComponent("database.csv")!
        let filePath = pathComponent.path
        let stream = OutputStream(toFileAtPath: filePath, append: false)!
        
        let writer = try! CSVWriter(stream: stream)
        
        for record in allRecords {
            let row: [String] = [
                record.hash,
                String(record.timestamp),
                String(record.latitude),
                String(record.longitude),
                String(record.medicalNeed),
                String(record.shelter),
                String(record.water),
                String(record.peopleCount),
                record.notes,
                String(record.hopCount + 1)
            ]
            try! writer.write(row: row)
        }
        
        writer.stream.close()
    }
    
    func fileData() -> Data {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        let pathComponent = url.appendingPathComponent("database.csv")!
        let filePath = pathComponent.path
        return try! Data(contentsOf: URL(string: filePath)!, options: [])
    }
}

extension Data {
    init(reading input: InputStream) {
        self.init()
        input.open()
        
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            self.append(buffer, count: read)
        }
        buffer.deallocate(capacity: bufferSize)
        
        input.close()
    }
}
