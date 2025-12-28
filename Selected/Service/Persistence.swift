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
import Defaults

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
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func updateClipHistoryData(_ clipData: ClipHistoryData, updateCount: Bool = true) {
        let ctx = container.viewContext
        if updateCount {
            clipData.lastCopiedAt = Date()
            clipData.numberOfCopies += 1
        }
        ctx.performAndWait {
            do {
                try ctx.save()
            } catch {
                fatalError("\(error)")
            }
        }
    }

    func store(_ clipData: ClipData) {
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.perform {
            let clipHistoryData = ClipHistoryData(context: backgroundContext)

            clipHistoryData.application = clipData.appBundleID
            clipHistoryData.firstCopiedAt = Date(timeIntervalSince1970: Double(clipData.timeStamp)/1000)
            clipHistoryData.lastCopiedAt = clipHistoryData.firstCopiedAt
            clipHistoryData.numberOfCopies = 1
            clipHistoryData.plainText = clipData.plainText
            clipHistoryData.url = clipData.url
            clipHistoryData.isPinned = false
            for item in clipData.items {
                let clipHistoryItem = ClipHistoryItem(context: backgroundContext)

                clipHistoryItem.data = item.data
                clipHistoryItem.type = item.type.rawValue
                clipHistoryItem.refer = clipHistoryData
                clipHistoryData.addToItems(clipHistoryItem)
            }
            clipHistoryData.md5 = clipHistoryData.MD5()

            if let got = self.get(byMD5: clipHistoryData.md5!, context: backgroundContext) {
                if got != clipHistoryData {
                    clipHistoryData.firstCopiedAt = got.firstCopiedAt
                    clipHistoryData.numberOfCopies = got.numberOfCopies + 1
                    clipHistoryData.isPinned = got.isPinned
                    backgroundContext.delete(got)
                    logger.debug("saved \(clipHistoryData.firstCopiedAt!) \(String(describing: got.firstCopiedAt))")
                }
            }

            do {
                try backgroundContext.save()
                logger.debug("saved \(clipHistoryData.md5!)")
            } catch {
                logger.error("saved: \(error)")
            }
        }
    }

//    func get(byMD5 md5: String) -> ClipHistoryData? {
//        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
//        fetchRequest.predicate = NSPredicate(format: "md5 = %@",md5 )
//        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
//        let ctx = PersistenceController.shared.container.viewContext
//        do{
//            let res = try ctx.fetch(fetchRequest)
//            return res.first
//        } catch {
//            fatalError("\(error)")
//        }
//    }

    private func get(byMD5 md5: String, context: NSManagedObjectContext) -> ClipHistoryData? {
        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        fetchRequest.predicate = NSPredicate(format: "md5 = %@",md5 )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
        do{
            let res = try context.fetch(fetchRequest)
            return res.first
        } catch {
            fatalError("\(error)")
        }
    }

    func delete(item: ClipHistoryData) {
        let ctx = PersistenceController.shared.container.viewContext
        ctx.performAndWait {
            do{
                ctx.delete(item)
                try ctx.save()
            } catch {
                fatalError("\(error)")
            }
        }
    }

    func deleteBefore(byDate date: Date){
        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        fetchRequest.predicate = NSPredicate(format: "lastCopiedAt < %@", date as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
        let ctx = PersistenceController.shared.container.viewContext

        ctx.performAndWait {
            do{
                let res = try ctx.fetch(fetchRequest)
                for data in res {
                    if data.isPinned {
                        continue
                    }
                    ctx.delete(data)
                }
                try ctx.save()
            } catch {
                fatalError("\(error)")
            }
        }
    }

    func startDailyTimer() {
        cleanTask()
        let timer = Timer.scheduledTimer(timeInterval: 86400, // 24 * 60 * 60 seconds
                                         target: self,
                                         selector: #selector(cleanTask),
                                         userInfo: nil,
                                         repeats: true)
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc func cleanTask() {
        var ago: Date
        switch Defaults[.clipboardHistoryTime] {
            case .OneDay:
                ago = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
            case .SevenDays:
                ago = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            case .ThirtyDays:
                ago = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            case .ThreeMonths:
                ago = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
            case .SixMonths:
                ago = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
            case .OneYear:
                ago = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        }
        deleteBefore(byDate: ago)
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
