import SwiftUI

class ClipViewModel: ObservableObject {
    @Published var selectedItem: ClipHistoryData?
    @Published var showsQuickPasteKeys = false
    var performShortcut: ((ClipShortcut) -> Bool)?
}
