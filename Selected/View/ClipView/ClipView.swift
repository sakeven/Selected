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
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        VStack(alignment: .leading){
            if let item = data.getItems().first {
                let type = NSPasteboard.PasteboardType(item.type!)
                previewView.id(data.objectID)
                Spacer()
                Divider()

                HStack {
                    Text("Application:")
                    Spacer()
                    getIcon(data.application!)
                    Text(getAppName(data.application!))
                }
                .frame(height: 17)

                HStack {
                    Text("Content type:")
                    Spacer()
                    if let text = data.plainText, isValidHttpUrl(text) {
                        Text("Link")
                    } else {
                        let str = "\(type)"
                        Text(NSLocalizedString(str, comment: ""))
                    }
                }
                .frame(height: 17)

                HStack {
                    Text("Date:")
                    Spacer()
                    Text("\(format(data.firstCopiedAt!))")
                }
                .frame(height: 17)

                if data.numberOfCopies > 1 {
                    HStack {
                        Text("Last copied:")
                        Spacer()
                        Text("\(format(data.lastCopiedAt!))")
                    }
                    .frame(height: 17)

                    HStack {
                        Text("Copied:")
                        Spacer()
                        Text("\(data.numberOfCopies) times")
                    }
                    .frame(height: 17)
                }

                if let url = data.url {
                    if type == .fileURL {
                        let url = URL(string: String(decoding: item.data!, as: UTF8.self))!
                        HStack {
                            Text("Path:")
                            Spacer()
                            Text(url.path().removingPercentEncoding!).lineLimit(1)
                        }
                        .frame(height: 17)
                    } else {
                        HStack {
                            Text("URL:")
                            Spacer()
                            Link(destination: URL(string: url)!, label: {
                                Text(url).lineLimit(1)
                            })
                        }
                        .frame(height: 17)
                    }
                }
            } else {
                EmptyView()
            }
        }
        .padding()
        .frame(width: 550)
    }

    private var previewView: some View {
        VStack{
            let item = data.getItems().first!
            let type = NSPasteboard.PasteboardType(item.type!)
            if type == .png {
                Image(nsImage: NSImage(data: item.data!)!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
        }
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
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)
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

// MARK: - 剪贴板项行（根据剪贴板数据类型展示不同内容）
struct ClipRowView: View {
    @ObservedObject var clip: ClipHistoryData

    var body: some View {
        HStack(spacing: 4) {
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .imageScale(.small)
                    .padding(.leading, 4)
            }

            rowContent
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        if let item = clip.getItems().first,
           let typeString = item.type {
            let type = NSPasteboard.PasteboardType(rawValue: typeString)

            switch type {
                case .png:
                    if let data = item.data,
                       let image = NSImage(data: data) {
                        let widthStr = valueFormatter.string(from: NSNumber(value: Double(image.size.width))) ?? ""
                        let heightStr = valueFormatter.string(from: NSNumber(value: Double(image.size.height))) ?? ""
                        Label {
                            Text("Image \(widthStr) * \(heightStr)")
                                .padding(.leading, 10)
                        } icon: {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    } else {
                        EmptyView()
                    }

                case .fileURL:
                    if let data = item.data,
                       let url = URL(string: String(decoding: data, as: UTF8.self)) {
                        Label {
                            Text(url.lastPathComponent.removingPercentEncoding ?? "")
                                .lineLimit(1)
                                .padding(.leading, 10)
                        } icon: {
                            Image(systemName: "doc.on.doc")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    } else {
                        EmptyView()
                    }

                case .rtf:
                    if let plainText = clip.plainText {
                        Label {
                            Text(plainText.trimmingCharacters(in: .whitespacesAndNewlines))
                                .lineLimit(1)
                                .padding(.leading, 10)
                        } icon: {
                            Image(systemName: "doc.richtext")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    } else {
                        EmptyView()
                    }

                case .string:
                    if let plainText = clip.plainText {
                        Label {
                            Text(plainText.trimmingCharacters(in: .whitespacesAndNewlines))
                                .lineLimit(1)
                                .padding(.leading, 10)
                        } icon: {
                            Image(systemName: "doc.plaintext")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    } else {
                        EmptyView()
                    }

                case .html:
                    if let plainText = clip.plainText {
                        Label {
                            Text(plainText.trimmingCharacters(in: .whitespacesAndNewlines))
                                .lineLimit(1)
                                .padding(.leading, 10)
                        } icon: {
                            Image(systemName: "circle.dashed.rectangle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    } else {
                        EmptyView()
                    }

                case .URL:
                    if let urlString = clip.url {
                        Label {
                            Text(urlString.trimmingCharacters(in: .whitespacesAndNewlines))
                                .lineLimit(1)
                                .padding(.leading, 10)
                        } icon: {
                            Image(systemName: "link")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    } else {
                        EmptyView()
                    }

                default:
                    EmptyView()
            }
        } else {
            EmptyView()
        }
    }
}

struct ClipView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ClipHistoryData.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: false)
        ],
        animation: .default)
    private var clips: FetchedResults<ClipHistoryData>

    @ObservedObject var viewModel = ClipViewModel.shared
    @FocusState private var isFocused: Bool

    @State private var searchText = ""
    @State private var localSelection: ClipHistoryData?

    // 过滤后的结果
    private var filteredClips: [ClipHistoryData] {
        if searchText.isEmpty {
            return Array(clips)
        } else {
            return clips.filter { clip in
                if let plainText = clip.plainText,
                   plainText.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let url = clip.url,
                   url.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
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
        ZStack {
            HStack(spacing: 0) {
                // 左侧列表
                VStack {
                    SearchBarView(searchText: $searchText, onArrowKey: handleArrowKey)

                    if filteredClips.isEmpty {
                        Text(searchText.isEmpty ? "Clipboard History" : "No results found")
                            .frame(width: 250)
                            .padding(.top)
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            List(filteredClips,
                                 id: \.self,
                                 selection: $localSelection) { clipData in
                                ClipRowView(clip: clipData)
                                    .frame(height: 30)
                                    .tag(clipData)
                                    .contextMenu {
                                        Button(action: {
                                            togglePin(clipData)
                                        }) {
                                            Label(clipData.isPinned ? String(localized: "clip.unpin") : String(localized: "clip.pin"), systemImage: "pin").labelStyle(.titleAndIcon)
                                        }
                                        Divider()
                                        Button(action: {
                                            delete(clipData)
                                        }) {
                                            Label("Delete", systemImage: "trash").labelStyle(.titleAndIcon)
                                        }
                                    }
                                    .background(.clear)
                            }
                                 .listStyle(.plain)
                                 .scrollContentBackground(.hidden)
                                 .listRowBackground(Color.clear)
                                 .background(.clear)
                                 .frame(width: 250)
                                 .frame(minWidth: 250, maxWidth: 250)
                                 .onChange(of: searchText) { _ in
                                     if !filteredClips.isEmpty {
                                         localSelection = filteredClips.first
                                         withAnimation {
                                             proxy.scrollTo(filteredClips.first, anchor: .top)
                                         }
                                     } else {
                                         localSelection = nil
                                     }
                                 }
                        }
                    }
                }

                // 右侧详情
                Group {
                    if let selected = localSelection {
                        ClipDataView(data: selected)
                    } else {
                        Text("Clipboard History")
                            .foregroundColor(.secondary)
                    }
                }

            }
        }
        .frame(width: 800, height: 400)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onAppear {
            localSelection = clips.first
            viewModel.selectedItem = localSelection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isFocused = true
            }
        }
        .onChange(of: localSelection) { newValue in
            viewModel.selectedItem = newValue
        }
        .focused($isFocused)
    }

    // MARK: - 方向键处理：现在改操作 localSelection，而不是直接改 viewModel
    private func handleArrowKey(_ direction: CustomSearchField.ArrowDirection) {
        guard !filteredClips.isEmpty else { return }

        if direction == .down {
            if let current = localSelection,
               let index = filteredClips.firstIndex(of: current),
               index < filteredClips.count - 1 {
                localSelection = filteredClips[index + 1]
            } else {
                localSelection = filteredClips.first
            }
        } else if direction == .up {
            if let current = localSelection,
               let index = filteredClips.firstIndex(of: current),
               index > 0 {
                localSelection = filteredClips[index - 1]
            }
        }
    }

    // MARK: - 删除逻辑，也改用 localSelection 作为参考
    private func delete(_ clipData: ClipHistoryData) {
        let currentSelection = localSelection
        let selectedItemIdx = currentSelection.flatMap { filteredClips.firstIndex(of: $0) } ?? 0
        let idx = filteredClips.firstIndex(of: clipData) ?? 0

        // 先算好删除后的选中索引
        let newIndexAfterDeletion: Int?
        if currentSelection == clipData {
            if filteredClips.count > idx + 1 {
                newIndexAfterDeletion = idx
            } else if idx > 0 {
                newIndexAfterDeletion = idx - 1
            } else {
                newIndexAfterDeletion = nil
            }
        } else if idx < selectedItemIdx {
            newIndexAfterDeletion = selectedItemIdx > 0 ? selectedItemIdx - 1 : 0
        } else {
            newIndexAfterDeletion = selectedItemIdx
        }

        PersistenceController.shared.delete(item: clipData)

        DispatchQueue.main.async {
            let newFiltered = self.filteredClips  // 删除后重新计算
            if let newIndex = newIndexAfterDeletion,
               newFiltered.indices.contains(newIndex) {
                self.localSelection = newFiltered[newIndex]
            } else if !newFiltered.isEmpty {
                self.localSelection = newFiltered.first
            } else {
                self.localSelection = nil
            }
        }
    }

    // MARK: - 置顶 / 取消置顶
    private func togglePin(_ clipData: ClipHistoryData) {
        clipData.isPinned.toggle()
        do {
            try viewContext.save()
        } catch {
            print("Failed to toggle pin: \(error)")
        }

        // 如果刚操作的是当前选中项，保证选中引用不变（指向最新的托管对象状态）
        viewModel.selectedItem = clipData
    }
}

#Preview {
    ClipView()
}
