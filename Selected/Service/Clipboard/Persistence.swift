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

    init(container: NSPersistentContainer = NSPersistentContainer(name: "ClipHistory")) {
        self.container = container
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
                AppLogger.clipboard.error("\(error)")
            }
        }
    }

    func store(_ clipData: ClipData) {
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.perform {
            self.store(clipData, in: backgroundContext)
        }
    }

    func store(_ clipData: ClipData, in backgroundContext: NSManagedObjectContext) {
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

        let shouldScheduleOcr = clipData.plainText == nil && clipData.ocrImage != nil
        let ocrImage = clipData.ocrImage
        let md5 = clipHistoryData.md5

        if let got = self.get(byMD5: clipHistoryData.md5!, context: backgroundContext) {
            if got != clipHistoryData {
                clipHistoryData.firstCopiedAt = got.firstCopiedAt
                clipHistoryData.numberOfCopies = got.numberOfCopies + 1
                clipHistoryData.isPinned = got.isPinned
                backgroundContext.delete(got)
                AppLogger.clipboard.debug("saved \(clipHistoryData.firstCopiedAt!) \(String(describing: got.firstCopiedAt))")
            }
        }

        do {
            try backgroundContext.save()
            AppLogger.clipboard.debug("saved \(clipHistoryData.md5!)")
            if let md5 = md5, let ocrImage = ocrImage, shouldScheduleOcr {
                self.scheduleImageOcr(for: md5, image: ocrImage)
            }
        } catch {
            AppLogger.clipboard.error("saved: \(error)")
        }
    }

    private func scheduleImageOcr(for md5: String, image: NSImage) {
        DispatchQueue.global(qos: .utility).async {
            let recognizedText = recognizeTextInImage(image)
            guard !recognizedText.isEmpty else { return }

            let context = self.container.newBackgroundContext()
            context.perform {
                let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
                fetchRequest.predicate = NSPredicate(format: "md5 = %@", md5)
                fetchRequest.fetchLimit = 1
                do {
                    if let clip = try context.fetch(fetchRequest).first {
                        clip.plainText = recognizedText
                        try context.save()
                        AppLogger.clipboard.debug("saved ocr text for \(md5)")
                    }
                } catch {
                    AppLogger.clipboard.error("save ocr text: \(error)")
                }
            }
        }
    }

    private func get(byMD5 md5: String, context: NSManagedObjectContext) -> ClipHistoryData? {
        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        fetchRequest.predicate = NSPredicate(format: "md5 = %@",md5 )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
        do{
            let res = try context.fetch(fetchRequest)
            return res.first
        } catch {
            AppLogger.clipboard.error("\(error)")
        }
        return nil
    }

    func delete(item: ClipHistoryData) {
        let ctx = container.viewContext
        ctx.performAndWait {
            do{
                ctx.delete(item)
                try ctx.save()
            } catch {
                AppLogger.clipboard.error("\(error)")
            }
        }
    }

    func deleteBefore(byDate date: Date){
        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        fetchRequest.predicate = NSPredicate(format: "lastCopiedAt < %@", date as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
        let ctx = container.viewContext

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
                AppLogger.clipboard.error("\(error)")
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
        deleteBefore(byDate: Defaults[.clipboardHistoryTime].cutoffDate(relativeTo: Date(), calendar: .current))
    }
}
