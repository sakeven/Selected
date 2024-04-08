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
    var data: ClipData
    
    var body: some View {
        VStack(alignment: .leading){
            let item = data.items.first!
            if item.type == .png {
                Image(nsImage: NSImage(data: item.data)!).resizable().aspectRatio(contentMode: .fit)
            } else if item.type == .rtf {
                RTFView(rtfData: item.data)
            } else if item.type == .fileURL {
                let url = URL(string: String(decoding: item.data, as: UTF8.self))!
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
                getIcon(data.appBundleID)
                Text(getAppName(data.appBundleID))
            }.frame(height: 17)
            
            HStack {
                Text("Content type:")
                Spacer()
                if let text = data.plainText, isValidHttpUrl(text) {
                    Text("Link")
                } else {
                    let str = "\(item.type)"
                    Text(NSLocalizedString(str, comment: ""))
                }
            }.frame(height: 17)
            
            HStack {
                Text("Date:")
                Spacer()
                Text("\(getDate(ts:data.timeStamp))")
            }.frame(height: 17)
            
            if let url = data.url {
                if item.type == .fileURL {
                    let url = URL(string: String(decoding: item.data, as: UTF8.self))!
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

func getDate(ts: Int64) -> Date {
    return Date(timeIntervalSince1970: TimeInterval(ts/1000))
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
    @Published var selectedItem: ClipData?
}


struct ClipView: View {
    var datas: [ClipData]
    
    @ObservedObject var viewModel = ClipViewModel.shared
    
    // 默认选择第一条，必须同时设置 List 和 NavigationLink 的 selection
    //    @State var selected : ClipData?
    var body: some View {
        NavigationView{
            List(datas, id: \.self, selection:  $viewModel.selectedItem){
                clipData in
                let item = clipData.items.first!
                NavigationLink(destination: ClipDataView(data: clipData), tag: clipData, selection:  $viewModel.selectedItem){
                    if item.type == .png {
                        let im = NSImage(data: item.data)!
                        let height = valueFormatter.string(from: NSNumber(value: Double(im.size.height)))
                        let width = valueFormatter.string(from: NSNumber(value: Double(im.size.width)))
                        Label(
                            title: { Text("Image \(width!) * \(height!)").padding(.leading, 10)},
                            icon: {
                                Image(nsImage: NSImage(data: item.data)!).resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                            }
                        )
                    } else if item.type == .fileURL {
                        let url = URL(string: String(decoding: item.data, as: UTF8.self))!
                        Label(
                            title: { Text(url.lastPathComponent.removingPercentEncoding!).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "doc.on.doc").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    } else if item.type == .rtf {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "doc.richtext").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    } else if item.type == .string {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "doc.plaintext").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    } else if item.type == .html {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "circle.dashed.rectangle").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    } else if item.type == .URL {
                        Label(
                            title: { Text(clipData.url!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "link").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    }
                }.frame(height: 30)
            }.frame(width: 250).frame(minWidth: 250, maxWidth: 250) .onAppear(){
                ClipViewModel.shared.selectedItem = datas.first
            }
            
            if datas.isEmpty {
                Text("Clipboard History")
            }
        }.frame(width: 800, height: 400)
    }
}

#Preview {
    ClipView(datas: ClipService.shared.getHistory())
}
