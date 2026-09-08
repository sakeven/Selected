import Foundation

func createTemporaryURLForData(_ data: Data, fileName: String) -> URL? {
    // 获取临时目录 URL
    let tempDirectoryURL = FileManager.default.temporaryDirectory

    // 创建新临时文件 URL
    let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)

    do {
        // 将数据写入临时文件
        try data.write(to: tempFileURL)
        return tempFileURL
    } catch {
        print("Error writing data to temporary file: \(error)")
        return nil
    }
}
