import SwiftUI

struct ClipActionBar: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        if data.isJSON {
            Button("Prettify JSON", systemImage: "curlybraces") {
                prettifyJSON()
            }
        }
    }

    private func prettifyJSON() {
        guard let text = data.plainText else { return }
        do {
            let pretty = try JSONFormatter.prettify(text)
            data.plainText = pretty
            let item = data.getItems().first
            item?.type = NSPasteboard.PasteboardType.string.rawValue
            item?.data = pretty.data(using: .utf8)
            PersistenceController.shared.updateClipHistoryData(data, updateCount: false)
        } catch {
        }
    }

}
