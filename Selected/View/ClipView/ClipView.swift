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
                ScrollView{
                    HStack{
                        Text(data.plainText!)
                    }
                }
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
                Text("\(data.firstCopiedAt!)")
            }.frame(height: 17)
            
            if data.numberOfCopies > 1 {
                HStack {
                    Text("Times copied:")
                    Spacer()
                    Text("\(data.numberOfCopies)")
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
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return FileManager.default.displayName(atPath: bundleURL.path)
    }
    
    private func getIcon(_ bundleID: String) -> some View {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return AnyView(
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path)).resizable().aspectRatio(contentMode: .fit).frame(width: 15, height: 15)
        )
    }
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
    
    // 维护一个 FetchRequest 实例
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipHistoryData.firstCopiedAt, ascending: false)],
        animation: .default)
    private var clips: FetchedResults<ClipHistoryData>
    
    
    // 默认选择第一条，必须同时设置 List 和 NavigationLink 的 selection
    //    @State var selected : ClipData?
    @ObservedObject var viewModel = ClipViewModel.shared
    
    var body: some View {
        NavigationView{
            List(clips, id: \.self, selection:  $viewModel.selectedItem){
                clipData in
                let item = clipData.getItems().first!
                NavigationLink(destination: ClipDataView(data: clipData), tag: clipData, selection:  $viewModel.selectedItem) {
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
                            Label(
                                title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                                icon: { Image(systemName: "circle.dashed.rectangle").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                            )
                        case .URL:
                            Label(
                                title: { Text(clipData.url!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                                icon: { Image(systemName: "link").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                            )
                        default:
                            EmptyView()
                    }
                }.frame(height: 30)
            }.frame(width: 250).frame(minWidth: 250, maxWidth: 250).onAppear(){
                ClipViewModel.shared.selectedItem = clips.first
            }
            
            if clips.isEmpty {
                Text("Clipboard History")
            }
        }.frame(width: 800, height: 400)
    }
}

#Preview {
    ClipView()
}
