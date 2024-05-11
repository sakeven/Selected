//
//  StarDict.swift
//  Selected
//
//  Created by sake on 2024/5/7.
//

import Foundation
import GRDB

struct Word: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "stardict"

    var id: Int
    var word: String
    var phonetic: String
    var translation: String
    var exchange: String
}

class StarDict {
    static let shared = StarDict()
    var databaseFileURL: URL
    
    init() {
        let fileManager = FileManager.default
        databaseFileURL = appSupportURL.appendingPathComponent("stardict.sqlite3")
        NSLog("databaseFileURL: \(databaseFileURL.path)")
        if let bundleDatabasePath = Bundle.main.path(forResource: "stardict", ofType: "tar.gz") {
            if !fileManager.fileExists(atPath: databaseFileURL.path) {
                extractTarGzFile(tarGzPath: bundleDatabasePath , destination: appSupportURL)
            }
        }
    }
    
    func query(word: String) throws -> Word?{
        let dbQueue = try DatabaseQueue(path: databaseFileURL.path)
        return try dbQueue.read { db in
            try Word.filter(Column("word") == word).fetchOne(db)
        }
    }
}

private func extractTarGzFile(tarGzPath: String, destination: URL) {
    // 创建一个 Process 来执行 tar 命令
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    process.arguments = ["-xzf", tarGzPath, "-C", destination.path]
    
    do {
        try process.run()
        process.waitUntilExit()  // 等待解压完成
        if process.terminationStatus == 0 {
            print("File successfully extracted.")
        } else {
            print("Error occurred during extraction. Status code: \(process.terminationStatus)")
        }
    } catch {
        print("Failed to start process: \(error)")
    }
}
