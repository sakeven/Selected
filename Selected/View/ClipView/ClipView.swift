//
//  ClipView.swift
//  Selected
//
//  Created by sake on 2024/4/7.
//

import Foundation
import SwiftUI


struct ClipDataView: View {
    var data: ClipData
    
    var body: some View {
        VStack(alignment: .leading){
            if data.png != nil {
                Image(nsImage: NSImage(data: data.png!)!).resizable().aspectRatio(contentMode: .fit)
            } else if data.rtf != nil {
                RTFView(rtfData: data.rtf!)
            } else if data.plainText != nil {
                ScrollView{
                    HStack{
                        Text(data.plainText!)
                        Spacer()
                    }
                }
            }
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
                let str = "\(data.types.first!)"
                Text(NSLocalizedString(str, comment: ""))
            }.frame(height: 17)
            
            HStack {
                Text("Date:")
                Spacer()
                Text("\(getDate(ts:data.timeStamp))")
            }.frame(height: 17)
            
            if let url = data.url {
                HStack {
                    Text("URL:")
                    Spacer()
                    Link(destination: URL(string: url)!, label: {
                        Text(url).lineLimit(1)
                    })
                }.frame(height: 17)
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

struct RTFView: NSViewRepresentable {
    var rtfData: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false // 设为false禁止编辑
        textView.autoresizingMask = [.width]
        textView.translatesAutoresizingMaskIntoConstraints = true
        if let attributedString =
            try? NSMutableAttributedString(data: rtfData.data(using: .utf8)!,
                                           options: [
                                            .documentType: NSAttributedString.DocumentType.rtf],
                                           documentAttributes: nil) {
            let originalRange = NSMakeRange(0, attributedString.length);
            attributedString.addAttribute(NSAttributedString.Key.backgroundColor,  value: NSColor.clear, range: originalRange)
            
            textView.textStorage?.setAttributedString(attributedString)
        }
        textView.drawsBackground = false // 确保不会绘制默认的背景
        textView.backgroundColor = .clear
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false // 确保不会绘制默认的背景
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 用于更新视图
    }
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
                NavigationLink(destination: ClipDataView(data: clipData), tag: clipData, selection:  $viewModel.selectedItem){
                    if clipData.types.first == .png {
                        Label(
                            title: { Text("Image").padding(.leading, 10)},
                            icon: {
                                Image(nsImage: NSImage(data: clipData.png!)!).resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                            }
                        )
                    } else if  clipData.types.first == .fileURL {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "doc.on.doc").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    }else if clipData.types.first == .rtf {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "doc.richtext").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    }else if
                        clipData.types.first == .string  {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "doc.plaintext").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    }else if
                                clipData.types.first == .html {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "text.quote").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
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
