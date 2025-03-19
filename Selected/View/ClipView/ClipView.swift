//
//  ClipView.swift
//  Selected
//
//  Created by sake on 2024/4/7.
//

import Foundation
import SwiftUI
import PDFKit

struct ClipDataView: View {
    var data: ClipHistoryData

    var body: some View {
        VStack(alignment: .leading){
            let item = data.getItems().first!
            let type = NSPasteboard.PasteboardType(item.type!)
            if type == .png {
                Image(nsImage: NSImage(data: item.data!)!).resizable().aspectRatio(contentMode: .fit)
            } else if type == .rtf {
                RTFView(rtfData: item.data!)
            } else if type == .fileURL {
                let url = URL(string: String(decoding: item.data!, as: UTF8.self))!
                let name = url.lastPathComponent.removingPercentEncoding!
                if name.hasSuffix(".pdf") {
                    PDFKitRepresentedView(url: url)
                } else {
                    QuickLookPreview(url: url)
                }
            } else if data.plainText != nil {
                TextView(text: data.plainText!)
            }

            Spacer()
            Divider()

            HStack {
                Text("Application:")
                Spacer()
                getIcon(data.application!)
                Text(getAppName(data.application!))
            }.frame(height: 17)

            HStack {
                Text("Content type:")
                Spacer()
                if let text = data.plainText, isValidHttpUrl(text) {
                    Text("Link")
                } else {
                    let str = "\(type)"
                    Text(NSLocalizedString(str, comment: ""))
                }
            }.frame(height: 17)

            HStack {
                Text("Date:")
                Spacer()
                Text("\(format(data.firstCopiedAt!))")
            }.frame(height: 17)

            if data.numberOfCopies > 1 {
                HStack {
                    Text("Last copied:")
                    Spacer()
                    Text("\(format(data.lastCopiedAt!))")
                }.frame(height: 17)
                HStack {
                    Text("Copied:")
                    Spacer()
                    Text("\(data.numberOfCopies) times")
                }.frame(height: 17)
            }

            if let url = data.url {
                if type == .fileURL {
                    let url = URL(string: String(decoding: item.data!, as: UTF8.self))!
                    HStack {
                        Text("Path:")
                        Spacer()
                        Text(url.path().removingPercentEncoding!).lineLimit(1)
                    }.frame(height: 17)
                } else {
                    HStack {
                        Text("URL:")
                        Spacer()
                        Link(destination: URL(string: url)!, label: {
                            Text(url).lineLimit(1)
                        })
                    }.frame(height: 17)
                }
            }
        }.padding().frame(width: 550)
    }

    private func getAppName(_ bundleID: String) -> String {
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return "Unknown"
        }
        return FileManager.default.displayName(atPath: bundleURL.path)
    }

    private func getIcon(_ bundleID: String) -> some View {
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else{
            return AnyView(EmptyView())
        }
        return AnyView(
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path)).resizable().aspectRatio(contentMode: .fit).frame(width: 15, height: 15)
        )
    }
}

func format(_ d: Date) -> String{
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    return dateFormatter.string(from: d)
}

func isValidHttpUrl(_ string: String) -> Bool {
    guard let url = URL(string: string) else {
        return false
    }

    guard let scheme = url.scheme, scheme == "http" || scheme == "https" else {
        return false
    }

    return url.host != nil
}


class ClipViewModel: ObservableObject {
    static let shared = ClipViewModel()
    @Published var selectedItem: ClipHistoryData?
}


struct ClipView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: false)],
        animation: .default)
    private var clips: FetchedResults<ClipHistoryData>

    @ObservedObject var viewModel = ClipViewModel.shared
    @FocusState private var isFocused: Bool

    // 添加搜索状态
    @State private var searchText = ""

    // 添加过滤后的结果计算属性
    private var filteredClips: [ClipHistoryData] {
        if searchText.isEmpty {
            return Array(clips)
        } else {
            return clips.filter { clip in
                // 搜索纯文本内容
                if let plainText = clip.plainText, plainText.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // 搜索 URL
                if let url = clip.url, url.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // 如果是文件，搜索文件名
                if let item = clip.getItems().first,
                   let type = item.type,
                   NSPasteboard.PasteboardType(type) == .fileURL,
                   let data = item.data,
                   let urlString = String(data: data, encoding: .utf8),
                   let url = URL(string: urlString),
                   url.lastPathComponent.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                return false
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // 添加搜索框
                HStack(spacing: 8){
                    CustomSearchField(text: $searchText, placeholder: "Search") { direction in
                        // 当检测到箭头按键时，根据方向更新选中项
                        guard !filteredClips.isEmpty else { return }
                        if direction == .down {
                            if let current = viewModel.selectedItem,
                               let index = filteredClips.firstIndex(of: current),
                               index < filteredClips.count - 1 {
                                viewModel.selectedItem = filteredClips[index + 1]
                            } else {
                                viewModel.selectedItem = filteredClips.first
                            }
                        } else if direction == .up {
                            if let current = viewModel.selectedItem,
                               let index = filteredClips.firstIndex(of: current),
                               index > 0 {
                                viewModel.selectedItem = filteredClips[index - 1]
                            }
                        }
                    }
                    .frame(height: 28)
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                .padding(.horizontal)
                .padding(.top, 2)

                if filteredClips.isEmpty {
                    Text(searchText.isEmpty ? "Clipboard History" : "No results found")
                        .frame(width: 250)
                        .padding(.top)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in

                        List(filteredClips, id: \.self, selection: $viewModel.selectedItem) { clipData in
                            let item = clipData.getItems().first!
                            NavigationLink(destination: ClipDataView(data: clipData), tag: clipData, selection: $viewModel.selectedItem) {
                                let type = NSPasteboard.PasteboardType(item.type!)
                                switch type {
                                    case .png:
                                        let im = NSImage(data: item.data!)!
                                        let height = valueFormatter.string(from: NSNumber(value: Double(im.size.height)))
                                        let width = valueFormatter.string(from: NSNumber(value: Double(im.size.width)))
                                        Label(
                                            title: { Text("Image \(width!) * \(height!)").padding(.leading, 10)},
                                            icon: {
                                                Image(nsImage: NSImage(data: item.data!)!).resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                                            }
                                        )
                                    case .fileURL:
                                        let url = URL(string: String(decoding: item.data!, as: UTF8.self))!
                                        Label(
                                            title: { Text(url.lastPathComponent.removingPercentEncoding!).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                                            icon: { Image(systemName: "doc.on.doc").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                                        )
                                    case .rtf:
                                        Label(
                                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                                            icon: { Image(systemName: "doc.richtext").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                                        )
                                    case .string:
                                        Label(
                                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                                            icon: { Image(systemName: "doc.plaintext").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                                        )
                                    case .html:
                                        if let plainText = clipData.plainText {
                                            Label(
                                                title: { Text(plainText.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                                                icon: { Image(systemName: "circle.dashed.rectangle").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                                            )
                                        }
                                    case .URL:
                                        Label(
                                            title: { Text(clipData.url!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                                            icon: { Image(systemName: "link").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                                        )
                                    default:
                                        EmptyView()
                                }
                            }
                            .frame(height: 30)
                            .contextMenu {
                                Button(action: {
                                    delete(clipData)
                                }){
                                    Text("Delete")
                                }
                            }
                        }
                        .frame(width: 250)
                        .frame(minWidth: 250, maxWidth: 250)
                        // 当搜索文本变化时，默认选择第一条并滚动到最上面
                        .onChange(of: searchText) { _ in
                            if !filteredClips.isEmpty {
                                viewModel.selectedItem = filteredClips.first
                                withAnimation {
                                    proxy.scrollTo(filteredClips.first, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                ClipViewModel.shared.selectedItem = clips.first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isFocused = true
                }
            }
            .focused($isFocused)
        }
        .frame(width: 800, height: 400)
    }

    func delete(_ clipData: ClipHistoryData) {
        if let selectedItem = viewModel.selectedItem {
            let selectedItemIdx = filteredClips.firstIndex(of: selectedItem) ?? 0
            let idx = filteredClips.firstIndex(of: clipData) ?? 0

            // 计算删除后，需要选中的新条目的索引
            let newIndexAfterDeletion: Int?
            if selectedItem == clipData {
                if filteredClips.count > idx + 1 {
                    newIndexAfterDeletion = idx // 选择下一个
                } else if idx > 0 {
                    newIndexAfterDeletion = idx - 1 // 选择前一个
                } else {
                    newIndexAfterDeletion = nil // 没有其他条目可选择
                }
            } else if idx < selectedItemIdx {
                newIndexAfterDeletion = selectedItemIdx > 0 ? selectedItemIdx - 1 : 0
            } else {
                newIndexAfterDeletion = selectedItemIdx
            }

            PersistenceController.shared.delete(item: clipData)

            // 在删除后更新选中项
            DispatchQueue.main.async {
                if let newIndex = newIndexAfterDeletion, filteredClips.indices.contains(newIndex) {
                    viewModel.selectedItem = filteredClips[newIndex]
                } else if !filteredClips.isEmpty {
                    viewModel.selectedItem = filteredClips.first
                } else {
                    viewModel.selectedItem = nil
                }
            }
        }
    }
}

#Preview {
    ClipView()
}

struct CustomSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search"
    var onArrowKey: (ArrowDirection) -> Void

    enum ArrowDirection {
        case up, down
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: CustomSearchField

        init(parent: CustomSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let searchField = notification.object as? NSSearchField {
                parent.text = searchField.stringValue
            }
        }

        // 拦截键盘方向键事件
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowKey(.up)
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowKey(.down)
                return true
            }
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.placeholderString = placeholder
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }
}
