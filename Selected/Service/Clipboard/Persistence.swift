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
    private let historyWriter: NSManagedObjectContext

    init(container: NSPersistentContainer = NSPersistentContainer(name: "ClipHistory")) {
        self.container = container
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        historyWriter = container.newBackgroundContext()
        historyWriter.automaticallyMergesChangesFromParent = true
    }

    func updateClipHistoryData(_ clipData: ClipHistoryData, updateCount: Bool = true) {
        let ctx = container.viewContext
        ctx.performAndWait {
            if updateCount {
                clipData.lastCopiedAt = Date()
                clipData.numberOfCopies += 1
            }
            do {
                try ctx.save()
            } catch {
                AppLogger.clipboard.error("\(error)")
            }
        }
    }

    func store(_ clipData: ClipData) {
        historyWriter.perform {
            self.store(clipData, in: self.historyWriter)
        }
    }

    func store(_ clipData: ClipData, in backgroundContext: NSManagedObjectContext) {
        let md5 = MD5(chunks: clipData.items.map(\.data))
        let copiedAt = Date(timeIntervalSince1970: Double(clipData.timeStamp) / 1000)
        do {
            let clip = try get(byMD5: md5, context: backgroundContext) ?? ClipHistoryData(context: backgroundContext)
            clip.md5 = md5
            clip.application = clipData.appBundleID
            clip.firstCopiedAt = clip.firstCopiedAt ?? copiedAt
            clip.lastCopiedAt = copiedAt
            clip.numberOfCopies += 1
            clip.url = clipData.url
            if clipData.plainText != nil || clipData.ocrImage == nil {
                clip.plainText = clipData.plainText
            }

            let existingItems = clip.getItems()
            if !existingItems.elementsEqual(clipData.items, by: { $0.type == $1.type.rawValue && $0.data == $1.data }) {
                for item in existingItems { backgroundContext.delete(item) }
                for item in clipData.items {
                    let storedItem = ClipHistoryItem(context: backgroundContext)
                    storedItem.data = item.data
                    storedItem.type = item.type.rawValue
                    clip.addToItems(storedItem)
                }
            }

            try backgroundContext.save()
            if clip.plainText == nil, let image = clipData.ocrImage {
                scheduleImageOcr(for: md5, image: image)
            }
        } catch {
            backgroundContext.rollback()
            AppLogger.clipboard.error("saved: \(error)")
        }
    }

    private func scheduleImageOcr(for md5: String, image: NSImage) {
        DispatchQueue.global(qos: .utility).async {
            let recognizedText = recognizeTextInImage(image)
            guard !recognizedText.isEmpty else { return }

            let context = self.historyWriter
            context.perform {
                do {
                    guard let clip = try self.get(byMD5: md5, context: context), clip.plainText == nil else { return }
                    clip.plainText = recognizedText
                    try context.save()
                    AppLogger.clipboard.debug("saved ocr text for \(md5)")
                } catch {
                    context.rollback()
                    AppLogger.clipboard.error("save ocr text: \(error)")
                }
            }
        }
    }

    private func get(byMD5 md5: String, context: NSManagedObjectContext) throws -> ClipHistoryData? {
        let fetchRequest = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        fetchRequest.predicate = NSPredicate(format: "md5 = %@", md5)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: true)]
        fetchRequest.fetchLimit = 1
        return try context.fetch(fetchRequest).first
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
