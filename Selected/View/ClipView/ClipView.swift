//
//  ClipView.swift
//  Selected
//
//  Created by sake on 2024/4/7.
//

import AppKit
import CoreData
import Defaults
import Foundation
import PDFKit
import SwiftUI

func format(_ d: Date) -> String {
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

private enum ClipDisplayKind {
    case color
    case file
    case image
    case link
    case text
    case richText
    case html
    case unknown

    var label: String {
        switch self {
        case .color: return String(localized: "Color")
        case .file: return String(localized: "File")
        case .image: return String(localized: "Image")
        case .link: return String(localized: "Link")
        case .text: return String(localized: "Plain Text")
        case .richText: return String(localized: "Rich Text")
        case .html: return String(localized: "HTML")
        case .unknown: return String(localized: "Clipboard Item")
        }
    }

    var tint: Color {
        switch self {
        case .color: return .green
        case .file: return .blue
        case .image: return .orange
        case .link: return .blue
        case .text: return .blue
        case .richText: return .purple
        case .html: return .mint
        case .unknown: return .gray
        }
    }

    var symbolName: String {
        switch self {
        case .color: return "circle.fill"
        case .file: return "doc.on.doc"
        case .image: return "photo"
        case .link: return "link"
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .html: return "circle.dashed.rectangle"
        case .unknown: return "doc"
        }
    }
}

private extension ColorScheme {
    var clipBackdropColors: [Color] {
        self == .dark
            ? [Color(red: 0.12, green: 0.14, blue: 0.18), Color(red: 0.09, green: 0.10, blue: 0.13)]
            : [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.91, green: 0.93, blue: 0.96)]
    }

    var clipShellStroke: Color {
        self == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.8)
    }

    var clipPanelFill: Color {
        self == .dark ? Color.white.opacity(0.025) : Color.white.opacity(0.4)
    }

    var clipPanelStroke: Color {
        self == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var clipDetailFill: Color {
        self == .dark ? Color.black.opacity(0.12) : Color.white.opacity(0.6)
    }

    var clipCardFill: Color {
        self == .dark ? Color.white.opacity(0.035) : Color.white.opacity(0.7)
    }

    var clipPreviewFill: Color {
        Color(nsColor: .textBackgroundColor)
    }

    var clipSelectedFill: Color {
        Color.accentColor.opacity(self == .dark ? 0.22 : 0.10)
    }

    var clipSelectedStroke: Color {
        Color.accentColor.opacity(self == .dark ? 0.55 : 0.35)
    }

    var clipDivider: Color {
        self == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    var clipPrimaryText: Color { .primary }
    var clipSecondaryText: Color { .secondary }

}

struct ClipView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ClipHistoryData.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: false)
        ],
        animation: .default
    )
    private var clips: FetchedResults<ClipHistoryData>

    @ObservedObject var viewModel = ClipViewModel.shared
    @FocusState private var isFocused: Bool

    @State private var searchText = ""
    @State private var localSelection: ClipHistoryData?
    @State private var aiRequest: ClipAIPromptView.Request?

    private var filteredClips: [ClipHistoryData] {
        if searchText.isEmpty {
            return Array(clips)
        }

        return clips.filter { clip in
            if let plainText = clip.plainText,
               plainText.localizedCaseInsensitiveContains(searchText) {
                return true
            }

            if let url = clip.url,
               url.localizedCaseInsensitiveContains(searchText) {
                return true
            }

            if let fileName = clip.fileURLValue?.lastPathComponent.removingPercentEncoding,
               fileName.localizedCaseInsensitiveContains(searchText) {
                return true
            }

            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Label("Clipboard", systemImage: "clipboard")
                    .font(.headline)
                    .foregroundStyle(.primary)

                SearchBarView(searchText: $searchText, onArrowKey: handleArrowKey)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(colorScheme.clipDivider).frame(height: 1)
            }

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 320)

                Rectangle()
                    .fill(colorScheme.clipDivider)
                    .frame(width: 1)

                detailPane
                    .frame(minWidth: 500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 16) {
                Label("clip.navigate", systemImage: "arrow.up.arrow.down")
                Button {
                    ClipWindowManager.shared.forceCloseWindow()
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: "Esc")
                            .monospaced()
                        Text("clip.dismiss")
                    }
                }
                .buttonStyle(.plain)
                .help("clip.dismiss.shortcut")
                Spacer()

                if let selected = localSelection {
                    ClipActionBar(data: selected)

                    Divider().frame(height: 16)

                    Button("clip.copy.short", systemImage: "doc.on.doc") {
                        ClipService.shared.restore(selected, paste: false)
                    }
                    .buttonStyle(.bordered)
                    .help("clip.copy")

                    Button {
                        togglePin(selected)
                    } label: {
                        Label(selected.isPinned ? String(localized: "clip.unpin") : String(localized: "clip.pin"), systemImage: selected.isPinned ? "pin.slash" : "pin")
                    }
                    .buttonStyle(.bordered)

                    Button("clip.paste", systemImage: "return") {
                        ClipService.shared.restore(selected, paste: true)
                    }
                    .buttonStyle(.borderedProminent)

                    Menu {
                        ClipActionsMenu(data: selected, onTogglePin: { togglePin(selected) }, onDelete: { delete(selected) }) { instruction, translation in
                            requestAI(selected, instruction: instruction, translation: translation)
                        }
                    } label: {
                        Label("clip.actions", systemImage: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(colorScheme.clipPanelFill)
            .overlay(alignment: .top) {
                Rectangle().fill(colorScheme.clipDivider).frame(height: 1)
            }
        }
        .frame(width: 960, height: 600)
        .sheet(item: $aiRequest) { request in
            ClipAIPromptView(data: request.data, instruction: request.instruction, translation: request.translation)
        }
        .background {
            LinearGradient(
                colors: colorScheme.clipBackdropColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(colorScheme.clipShellStroke, lineWidth: 1)
        }
        .onAppear {
            localSelection = clips.first
            viewModel.selectedItem = localSelection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onChange(of: localSelection) { _, newValue in
            viewModel.selectedItem = newValue
        }
        .focused($isFocused)
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Clipboard History")
                Spacer()
                Text(filteredClips.count, format: .number)
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)

            if filteredClips.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("clip.empty.title", systemImage: "clipboard", description: Text("clip.empty.description"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredClips, id: \.objectID) { clipData in
                                Button {
                                    localSelection = clipData
                                } label: {
                                    ClipRowView(
                                        clip: clipData,
                                        isSelected: localSelection?.objectID == clipData.objectID
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(clipData.objectID)
                                .contextMenu {
                                    ClipActionsMenu(data: clipData, onTogglePin: { togglePin(clipData) }, onDelete: { delete(clipData) }) { instruction, translation in
                                        requestAI(clipData, instruction: instruction, translation: translation)
                                    }
                                }
                            }
                        }
                        .padding(2)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: localSelection?.objectID.uriRepresentation()) {
                        guard let selected = localSelection else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.14)) {
                            proxy.scrollTo(selected.objectID, anchor: .center)
                        }
                    }
                }
            }
        }
        .onChange(of: searchText) {
            localSelection = filteredClips.first
        }
        .padding(.vertical, 8)
        .padding(.trailing, 10)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selected = localSelection {
            ClipDataView(data: selected) { instruction, translation in
                requestAI(selected, instruction: instruction, translation: translation)
            }
        } else {
            ContentUnavailableView("clip.preview.empty", systemImage: "doc.text.magnifyingglass", description: Text("clip.preview.description"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

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
        } else if let current = localSelection,
                  let index = filteredClips.firstIndex(of: current),
                  index > 0 {
            localSelection = filteredClips[index - 1]
        }
    }

    private func delete(_ clipData: ClipHistoryData) {
        let currentSelection = localSelection
        let selectedItemIdx = currentSelection.flatMap { filteredClips.firstIndex(of: $0) } ?? 0
        let idx = filteredClips.firstIndex(of: clipData) ?? 0

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
            let newFiltered = filteredClips
            if let newIndex = newIndexAfterDeletion,
               newFiltered.indices.contains(newIndex) {
                localSelection = newFiltered[newIndex]
            } else if let first = newFiltered.first {
                localSelection = first
            } else {
                localSelection = nil
            }
        }
    }

    private func requestAI(_ clip: ClipHistoryData, instruction: String, translation: Bool) {
        if instruction.isEmpty {
            aiRequest = ClipAIPromptView.Request(data: clip, instruction: instruction, translation: translation)
        } else {
            ActionRequest.ai(instruction: instruction, translation: translation).perform(input: ActionInput(clip: clip),
                                                                                       target: ClipWindowManager.shared.actionTarget ?? ActionTarget())
        }
    }

    private func togglePin(_ clipData: ClipHistoryData) {
        clipData.isPinned.toggle()
        do {
            try viewContext.save()
        } catch {
            print("Failed to toggle pin: \(error)")
        }

        localSelection = clipData
        viewModel.selectedItem = clipData
    }
}

private struct ClipRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var clip: ClipHistoryData
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(clip.displayKind.tint.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay {
                    if clip.displayKind == .image,
                       let imageData = clip.primaryItem?.data,
                       let image = NSImage(data: imageData) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if clip.displayKind == .color, let color = clip.colorValue {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: color))
                            .padding(3)
                    } else {
                        ClipKindIcon(kind: clip.displayKind)
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(clip.rowTitle)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    Text(clip.contentTypeLabel)
                    Text("·")
                    Text(clip.appDisplayName)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(Text("clip.pinned"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 58)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? colorScheme.clipSelectedFill : (isHovered ? colorScheme.clipCardFill : .clear))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? colorScheme.clipSelectedStroke : .clear, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct ClipKindIcon: View {
    let kind: ClipDisplayKind

    var body: some View {
        if kind == .color {
            Circle()
                .fill(kind.tint)
                .frame(width: 12, height: 12)
        } else {
            Image(systemName: kind.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(kind.tint)
        }
    }
}

struct ClipDataView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData
    @Default(.aiService) private var aiService
    @State private var showActions = false
    let onAIRequest: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Label(data.contentTypeLabel, systemImage: data.displayKind.symbolName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(data.displayKind.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(data.displayKind.tint.opacity(0.10), in: Capsule())

                Spacer()

                Button("Process content", systemImage: "wand.and.stars") { showActions = true }
                    .buttonStyle(SettingsButtonStyle(emphasis: .primary))
                    .tint(.blue)
                    .popover(isPresented: $showActions) {
                        ContentActionPicker(input: ActionInput(clip: data)) { request in
                            showActions = false
                            request.perform(input: ActionInput(clip: data), target: ClipWindowManager.shared.actionTarget ?? ActionTarget())
                        }
                    }

                if data.isPinned {
                    Label("clip.pinned", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ClipPreviewStage(data: data)
                .id(data.MD5())
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colorScheme.clipPreviewFill, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(colorScheme.clipPanelStroke, lineWidth: 1)
                }
                .clipped()

            if let kind = data.aiContentKind(openAI: aiService == "OpenAI") {
                HStack(spacing: 8) {
                    Button("clip.ai.ask", systemImage: "sparkles") {
                        onAIRequest("", false)
                    }
                    .tint(.accentColor)

                    if kind == .text || kind == .document {
                        Button("clip.ai.summarize", systemImage: "list.bullet.rectangle") {
                            onAIRequest(String(localized: "clip.ai.prompt.summarize"), false)
                        }
                    } else {
                        Button("clip.ai.explain", systemImage: "text.magnifyingglass") {
                            onAIRequest(String(localized: "clip.ai.prompt.explain"), false)
                        }
                    }

                    if kind == .image || kind == .document {
                        Button("clip.ai.extract", systemImage: "text.viewfinder") {
                            onAIRequest(String(localized: "clip.ai.prompt.extract"), false)
                        }
                    } else if kind == .text {
                        Button("clip.ai.polish", systemImage: "pencil.line") {
                            onAIRequest(String(localized: "clip.ai.prompt.polish"), false)
                        }
                    }

                    if kind != .code && kind != .link {
                        Menu {
                            Button("clip.ai.translateChinese") {
                                onAIRequest(String(localized: "clip.ai.prompt.translateChinese"), true)
                            }
                            Button("clip.ai.translateEnglish") {
                                onAIRequest(String(localized: "clip.ai.prompt.translateEnglish"), true)
                            }
                        } label: {
                            Label("clip.ai.translate", systemImage: "character.bubble")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }

                    Spacer(minLength: 0)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .font(.callout)
            }

            ClipMetadataCard(data: data)

        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(colorScheme.clipDetailFill, in: RoundedRectangle(cornerRadius: 16))
        .padding(.leading, 12)
    }
}

private struct ClipMetadataCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            applicationRow

            ClipMetadataRow(title: "Date:") {
                Text(data.firstCopiedText)
            }

            if let lastCopiedText = data.lastCopiedText {
                ClipMetadataRow(title: "Last copied:") {
                    Text(lastCopiedText)
                }
            }

            ClipMetadataRow(title: "Copied:") {
                Text(data.copiesText)
            }

            if let locationInfo = data.locationInfo {
                ClipMetadataRow(title: "\(locationInfo.title):") {
                    Text(locationInfo.value)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(colorScheme.clipDivider).frame(height: 1)
        }
    }

    private var applicationRow: some View {
        ClipMetadataRow(title: "Application:") {
            HStack(spacing: 8) {
                if let icon = data.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Text(data.appDisplayName)
                    .font(.body.weight(.medium))
            }
        }
    }
}

private struct ClipPreviewStage: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        Group {
            switch data.displayKind {
            case .color:
                ClipColorPreview(data: data)
            case .file:
                ClipFilePreview(data: data)
            case .image:
                ClipImagePreview(data: data)
            case .link:
                ClipLinkPreview(data: data)
            case .text, .richText, .html, .unknown:
                ClipTextPreview(data: data)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipColorPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width * 0.56, geometry.size.height * 0.9)

            HStack {
                Spacer()
                Circle()
                    .fill(data.colorValue.map(Color.init(nsColor:)) ?? .green)
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .stroke(colorScheme.clipSelectedStroke, lineWidth: 1)
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipFilePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        if let url = data.fileURLValue {
            if url.pathExtension.lowercased() == "pdf" {
                PDFKitRepresentedView(url: url)
            } else {
                QuickLookPreview(url: url)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundStyle(data.displayKind.tint)

                Text(data.detailTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(colorScheme.clipPrimaryText)
                    .lineLimit(2)

                if let locationInfo = data.locationInfo {
                    Text(locationInfo.value)
                        .font(.body)
                        .foregroundStyle(colorScheme.clipSecondaryText)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ClipImagePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        if let imageData = data.primaryItem?.data,
           let image = NSImage(data: imageData) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .foregroundStyle(colorScheme.clipPrimaryText.opacity(0.84))

                Text(data.detailTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(colorScheme.clipPrimaryText)
                    .lineLimit(2)

                if let locationInfo = data.locationInfo {
                    Text(locationInfo.value)
                        .font(.body)
                        .foregroundStyle(colorScheme.clipSecondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipLinkPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(data.detailTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(colorScheme.clipPrimaryText)
                .lineLimit(2)

            if let previewText = data.cleanedPreviewText,
               previewText != data.displayURLString {
                Text(previewText)
                    .font(.body)
                    .foregroundStyle(colorScheme.clipPrimaryText.opacity(0.9))
                    .lineLimit(4)
            }

            Spacer(minLength: 0)

            if let urlString = data.displayURLString,
               let url = URL(string: urlString),
               isValidHttpUrl(urlString) {
                Link(destination: url) {
                    Text(urlString)
                        .font(.callout)
                        .foregroundStyle(colorScheme.clipSecondaryText)
                        .lineLimit(1)
                }
            } else if let urlString = data.displayURLString {
                Text(urlString)
                    .font(.callout)
                    .foregroundStyle(colorScheme.clipSecondaryText)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ClipTextPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        if let plainText = data.plainText, !plainText.isEmpty {
            TextView(text: plainText, font: data.isJSON ? .monospacedSystemFont(ofSize: 14, weight: .regular) : .systemFont(ofSize: 14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(data.detailTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(colorScheme.clipSecondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipMetadataRow<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(LocalizedStringKey(title))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Spacer(minLength: 0)

            content
                .font(.body)
                .foregroundStyle(colorScheme.clipPrimaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension ClipHistoryData {
    var primaryItem: ClipHistoryItem? {
        getItems().first
    }

    var primaryPasteboardType: NSPasteboard.PasteboardType? {
        guard let type = primaryItem?.type else { return nil }
        return NSPasteboard.PasteboardType(rawValue: type)
    }

    var displayKind: ClipDisplayKind {
        guard let type = primaryPasteboardType else {
            if let plainText = plainText, isValidHttpUrl(plainText) {
                return .link
            }
            return plainText == nil ? .unknown : .text
        }

        switch type {
        case .color:
            return .color
        case .png, .tiff:
            return .image
        case .fileURL:
            return .file
        case .rtf:
            return .richText
        case .html:
            return .html
        case .URL:
            return .link
        case .string:
            if let plainText = plainText, isValidHttpUrl(plainText) {
                return .link
            }
            return .text
        default:
            return url == nil ? .unknown : .link
        }
    }

    var contentTypeLabel: String {
        displayKind.label
    }

    var cleanedPreviewText: String? {
        guard let plainText else { return nil }
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var rowTitle: String {
        switch displayKind {
        case .color:
            return String(localized: "Color")
        case .file:
            return fileURLValue?.lastPathComponent.removingPercentEncoding ?? "File"
        case .image:
            return imageSizeText.map { "\(String(localized: "Image")) \($0)" } ?? String(localized: "Image")
        case .link:
            return displayURLString ?? cleanedPreviewText?.removingAllNewlines() ?? "Link"
        case .text, .richText, .html:
            return cleanedPreviewText?.removingAllNewlines() ?? contentTypeLabel
        case .unknown:
            return cleanedPreviewText?.removingAllNewlines() ?? displayURLString ?? "Clipboard Item"
        }
    }

    var detailTitle: String {
        switch displayKind {
        case .file:
            return fileURLValue?.lastPathComponent.removingPercentEncoding ?? rowTitle
        default:
            return rowTitle
        }
    }

    var fileURLValue: URL? {
        guard primaryPasteboardType == .fileURL,
              let data = primaryItem?.data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return URL(string: string)
    }

    var displayURLString: String? {
        if displayKind == .file {
            if let fileURLValue {
                return fileURLValue.path.removingPercentEncoding ?? fileURLValue.path
            }
            return nil
        }

        if let url, !url.isEmpty {
            return url
        }

        if let cleanedPreviewText, isValidHttpUrl(cleanedPreviewText) {
            return cleanedPreviewText
        }

        return nil
    }

    var imageSizeText: String? {
        guard let data = primaryItem?.data,
              let image = NSImage(data: data) else {
            return nil
        }

        let width = valueFormatter.string(from: NSNumber(value: Double(image.size.width))) ?? ""
        let height = valueFormatter.string(from: NSNumber(value: Double(image.size.height))) ?? ""
        guard !width.isEmpty, !height.isEmpty else { return nil }
        return "\(width) × \(height)"
    }

    var colorValue: NSColor? {
        guard let data = primaryItem?.data else { return nil }
        return decodeNSColor(from: data)
    }

    var appDisplayName: String {
        guard let bundleID = application,
              let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return "Unknown"
        }
        return FileManager.default.displayName(atPath: bundleURL.path)
    }

    var appIcon: NSImage? {
        guard let bundleID = application,
              let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: bundleURL.path)
    }

    var firstCopiedText: String {
        firstCopiedAt.map(format) ?? "-"
    }

    var lastCopiedText: String? {
        guard numberOfCopies > 1, let lastCopiedAt else { return nil }
        return format(lastCopiedAt)
    }

    var copiesText: String {
        if numberOfCopies == 1 {
            return "1"
        }
        return String(format: String(localized: "%d times"), numberOfCopies)
    }

    var locationInfo: (title: String, value: String)? {
        switch displayKind {
        case .file:
            guard let fileURLValue else { return nil }
            return ("Path", fileURLValue.path.removingPercentEncoding ?? fileURLValue.path)
        case .image:
            guard let imageSizeText else { return nil }
            return ("Size", imageSizeText)
        case .link:
            guard let displayURLString else { return nil }
            return ("URL", displayURLString)
        default:
            return nil
        }
    }
}

#Preview {
    ClipView()
}

extension ClipHistoryData {
    var isJSON: Bool {
        guard let text = plainText else { return false }
        return JSONFormatter.isValidJSON(text)
    }
}

struct ClipActionBar: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        HStack(spacing: 8) {
            if data.isJSON {
                Button("Prettify JSON") {
                    prettifyJSON()
                }
                .buttonStyle(.bordered)
            }

            if data.plainText != nil {
                Button("Paste plain text") {
                    pastePlainText()
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.regular)
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

    private func pastePlainText() {
        ClipWindowManager.shared.forceCloseWindow()
        guard let text = data.plainText else { return }
        pasteText(text)
    }
}

extension String {
    func removingAllNewlines() -> String {
        self
            .replacingOccurrences(of: "\r\n", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }
}

func decodeNSColor(from data: Data) -> NSColor? {
    NSColor(pasteboardPropertyList: data, ofType: .color)
}

func colorToData(color: NSColor) -> Data? {
    do {
        return try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    } catch {
        logger.error("convert color to Data: \(error)")
        return nil
    }
}

func swiftUIColor(from c1: NSColor) -> NSColor {
    let count = c1.numberOfComponents
    var rawComponents = Array<CGFloat>(repeating: 0, count: count)

    c1.getComponents(&rawComponents)

    let normalizedComponents = rawComponents.map { $0 > 1.0 ? $0 / 255.0 : $0 }

    let correctedColor = NSColor(
        colorSpace: c1.colorSpace,
        components: normalizedComponents,
        count: normalizedComponents.count
    )

    if let sRGBColor = correctedColor.usingColorSpace(.sRGB) {
        return sRGBColor
    }
    return c1
}
