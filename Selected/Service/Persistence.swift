//
//  Persistence.swift
//  Selected
//
//  Created by sake on 2024/4/8.
//

import Foundation
import CoreData
import Cocoa
import SwiftUI

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "ClipHistory")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
    
    func updateClipHistoryData(_ clipData: ClipHistoryData) {
        let ctx = container.viewContext
        clipData.lastCopiedAt = Date()
        clipData.numberOfCopies += 1
        do {
            try ctx.save()
            NSLog("saved")
        } catch {
            fatalError("\(error)")
        }
    }
    
    func store(_ clipData: ClipData) {
        let ctx = PersistenceController.shared.container.viewContext
        let clipHistoryData =
        NSEntityDescription.insertNewObject(
            forEntityName: "ClipHistoryData", into: ctx)
          as! ClipHistoryData

        clipHistoryData.application = clipData.appBundleID
        clipHistoryData.firstCopiedAt = Date(timeIntervalSince1970: Double(clipData.timeStamp)/1000)
        clipHistoryData.lastCopiedAt = clipHistoryData.firstCopiedAt
        clipHistoryData.numberOfCopies = 1
        clipHistoryData.plainText = clipData.plainText
        clipHistoryData.url = clipData.url
        for item in clipData.items {
            let clipHistoryItem =
            NSEntityDescription.insertNewObject(
                forEntityName: "ClipHistoryItem", into: ctx)
              as! ClipHistoryItem
            
            clipHistoryItem.data = item.data
            clipHistoryItem.type = item.type.rawValue
            clipHistoryItem.refer = clipHistoryData
            clipHistoryData.addToItems(clipHistoryItem)
        }
        clipHistoryData.md5 = clipHistoryData.MD5()
        if let got = get(byMD5: clipHistoryData.md5!) {
            if got != clipHistoryData {
                clipHistoryData.firstCopiedAt = got.firstCopiedAt
                clipHistoryData.numberOfCopies = got.numberOfCopies + 1
                ctx.delete(got)
                NSLog("saved \(clipHistoryData.firstCopiedAt!) \(got.firstCopiedAt!)")
            }
        }
        do {
            try ctx.save()
            NSLog("saved \(clipHistoryData.md5!)")
        } catch {
            fatalError("\(error)")
        }
    }
    
    func get(byMD5 md5: String) -> ClipHistoryData? {
        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        fetchRequest.predicate = NSPredicate(format: "md5 = %@",md5 )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
        let ctx = PersistenceController.shared.container.viewContext
        do{
            let res = try ctx.fetch(fetchRequest)
            return res.first
        } catch {
            fatalError("\(error)")
        }
    }
    
    func deleteBefore(byDate date: Date){
        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        fetchRequest.predicate = NSPredicate(format: "lastCopiedAt < %@", date as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
        let ctx = PersistenceController.shared.container.viewContext
        do{
            let res = try ctx.fetch(fetchRequest)
            for data in res {
                ctx.delete(data)
            }
            try ctx.save()
        } catch {
            fatalError("\(error)")
        }
    }
    
    func startDailyTimer() {
        dailyTask()
        let timer = Timer.scheduledTimer(timeInterval: 86400, // 24 * 60 * 60 seconds
                                         target: self,
                                         selector: #selector(dailyTask),
                                         userInfo: nil,
                                         repeats: true)
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc private func dailyTask() {
        // 清理 7 天前的
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        deleteBefore(byDate: sevenDaysAgo)
    }
}


import CryptoKit


func MD5(string: String) -> String {
    var md5 = Insecure.MD5()
    md5.update(data: Data(string.utf8))
    let digest = md5.finalize()
    return digest.map {
        String(format: "%02hhx", $0)
    }.joined()
}


extension ClipHistoryData {
    func getItems() -> [ClipHistoryItem] {
        if let items = items {
            return items.array as! [ClipHistoryItem]
        }
        return []
    }
    
    func MD5() -> String {
        var md5 = Insecure.MD5()
        for item in getItems(){
            md5.update(data: item.data!)
        }
        let digest = md5.finalize()
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}
