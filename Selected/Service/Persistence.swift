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

struct PersistenceController {
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
        
        do {
            try ctx.save()
            NSLog("saved")
        } catch {
            fatalError("\(error)")
        }
    }
}






extension ClipHistoryData {
    func getItems() -> [ClipHistoryItem] {
        if let items = items {
            return items.array as! [ClipHistoryItem]
        }
        return []
    }
}
