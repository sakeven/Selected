//
//  ChatInputView.swift
//  Selected
//
//  Created by sake on 14/12/25.
//


import SwiftUI
import PhotosUI

struct ChatInputView: View {
    @ObservedObject var viewModel: MessageViewModel
    @State private var newText = ""
    @State private var task: Task<Void, Never>? = nil
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var pickedImages: [PickedImage] = []
    @State private var pickedFiles: [PickedFile] = []
    @State private var isImporting = false
    @State private var showImportError = false
    @State private var importError = ""
    @State private var showMissingTextAlert = false
    @State private var showFileImporter = false

    var onCancel: (() -> Void)?

    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !pickedFiles.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(pickedFiles) { file in
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                Text(file.attachment.filename)
                                    .font(.callout)
                                    .lineLimit(1)
                                Button { pickedFiles.removeAll { $0.id == file.id } } label: {
                                    Label("chat.removeFile", systemImage: "xmark")
                                        .labelStyle(.iconOnly)
                                        .font(.caption)
                                        .frame(width: 22, height: 22)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.inProgress || isImporting)
                            }
                            .padding(.leading, 10)
                            .padding(.trailing, 4)
                            .padding(.vertical, 6)
                            .background(.primary.opacity(0.04), in: .rect(cornerRadius: 10))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if !pickedImages.isEmpty { previewHeader }
            if isImporting {
                ProgressView("chat.preparingAttachments")
                    .controlSize(.small)
            }
            composerEditor

            HStack(spacing: 6) {
                PhotosPicker(selection: $selectedPickerItems, maxSelectionCount: 5, matching: .images) {
                    composerAccessoryButton(title: "chat.photos", systemImage: "photo")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inProgress || isImporting)
                .help("chat.photos")
                .onChange(of: selectedPickerItems) { _, items in
                    loadImagesFromPhotosPicker(items)
                    selectedPickerItems = []
                }

                Button { showFileImporter = true } label: {
                    composerAccessoryButton(title: "chat.addAttachments", systemImage: "paperclip")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inProgress || isImporting)
                .help("chat.addAttachments")

                Spacer()
                Text("chat.sendHint")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button {
                    if viewModel.inProgress { cancel() } else { submitMessage() }
                } label: {
                    Label(viewModel.inProgress ? "chat.stop" : "chat.send", systemImage: viewModel.inProgress ? "stop.fill" : "arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.black : .white)
                        .frame(width: 34, height: 34)
                        .background(primaryActionDisabled ? Color.secondary.opacity(0.25) : Color.primary, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(primaryActionDisabled)
                .help(viewModel.inProgress ? "chat.stop" : "chat.send")
            }
        }
        .padding(14)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.primary.opacity(isInputFocused ? 0.2 : 0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): loadFiles(urls)
            case .failure(let error):
                importError = error.localizedDescription
                showImportError = true
            }
        }
        .alert("Text content needs to be entered.", isPresented: $showMissingTextAlert) {}
        .alert("chat.attachmentError", isPresented: $showImportError) {} message: { Text(importError) }
    }

    func cancel() {
        task?.cancel()
        onCancel?()
    }

    private func loadFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let openAI = viewModel.usesOpenAIFileInputs
        isImporting = true
        Task {
            defer { isImporting = false }
            var errors: [String] = []
            for url in urls {
                do {
                    let content = try await Task.detached(priority: .userInitiated) {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        return try ClipAIContent.load(items: [ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))], plainText: nil, openAI: openAI)
                    }.value
                    let files = content.images.isEmpty
                        ? (content.files.isEmpty ? [AIFileAttachment(filename: url.lastPathComponent, data: Data(content.text.utf8), mimeType: "text/plain")] : content.files)
                        : []
                    let addedBytes = content.images.reduce(0) { $0 + $1.count } + files.reduce(0) { $0 + $1.data.count }
                    guard attachmentBytes + addedBytes < (openAI ? 50_000_000 : 23_000_000) else {
                        throw ClipAIContent.ContentError.tooLarge
                    }
                    pickedImages += content.images.map { PickedImage(data: $0) }
                    pickedFiles += files.map { PickedFile(attachment: $0) }
                } catch {
                    errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            if !errors.isEmpty {
                importError = errors.joined(separator: "\n")
                showImportError = true
            }
        }
    }

    private func loadImagesFromPhotosPicker(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isImporting = true
        Task {
            defer { isImporting = false }
            for item in items {
                do {
                    guard let rawData = try await item.loadTransferable(type: Data.self),
                          let nsImage = NSImage(data: rawData),
                          let jpegData = nsImage.openAIReadyImageData() else {
                        throw ClipAIContent.ContentError.invalidImage
                    }
                    guard attachmentBytes + jpegData.count < (viewModel.usesOpenAIFileInputs ? 50_000_000 : 23_000_000) else {
                        throw ClipAIContent.ContentError.tooLarge
                    }
                    pickedImages.append(PickedImage(data: jpegData))
                } catch {
                    importError = error.localizedDescription
                    showImportError = true
                }
            }
        }
    }

    func submitMessage() {
        guard !viewModel.inProgress, !isImporting else { return }
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showMissingTextAlert = true
            return
        }

        let attachments = pickedImages.map(\.data)
        let files = pickedFiles.map(\.attachment)

        newText = ""
        pickedImages.removeAll()
        pickedFiles.removeAll()
        selectedPickerItems.removeAll()

        task = Task {
            logger.debug("attachments: \(attachments.count)")
            await viewModel.submit(message: .init(text: text, images: attachments, files: files))
        }
    }

    private var composerEditor: some View {
        ZStack(alignment: .topLeading) {
            if newText.isEmpty {
                Text("chat.input.placeholder")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 5)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $newText)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .accessibilityLabel(Text("chat.input.label"))
                .onKeyPress(.return, phases: .down) { keyPress in
                    guard keyPress.modifiers.contains(.command) else { return .ignored }
                    submitMessage()
                    return .handled
                }
        }
        .font(.system(size: 14))
        .frame(height: 72, alignment: .topLeading)
    }

    private var previewHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pickedImages) { image in
                    ZStack(alignment: .topTrailing) {
                        if let nsImage = NSImage(data: image.data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            Color.gray.frame(width: 72, height: 72)
                        }
                        Button {
                            removePickedImage(image)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .accessibilityLabel(Text("chat.removeImage"))
                                .foregroundStyle(.white, Color.black.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                }
            }
        }
    }

    private func removePickedImage(_ image: PickedImage) {
        if let index = pickedImages.firstIndex(where: { $0.id == image.id }) {
            pickedImages.remove(at: index)
        }
    }

    private var attachmentBytes: Int {
        pickedImages.reduce(0) { $0 + $1.data.count } + pickedFiles.reduce(0) { $0 + $1.attachment.data.count }
    }

    private var primaryActionDisabled: Bool {
        if viewModel.inProgress {
            return false
        }
        return isImporting || newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func composerAccessoryButton(title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .contentShape(.rect)
    }

}

private struct PickedFile: Identifiable {
    let id = UUID()
    let attachment: AIFileAttachment
}

struct PickedImage: Identifiable {
    let id = UUID()
    let data: Data
}

// NSImage -> JPEG
extension NSImage {
    func jpegData(compression: CGFloat = 0.85) -> Data? {
        guard
            let tiff = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compression]
        )
    }

    // MARK: - 1. 计算目标尺寸（只缩小，不放大）

    /// 根据 OpenAI 要求计算等比缩放后的尺寸（短边 ≤ maxShortSide，长边 ≤ maxLongSide）
    func scaledSizeForOpenAI(
        maxShortSide: CGFloat = 768,
        maxLongSide: CGFloat = 2000
    ) -> CGSize? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width  = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let minSide = min(width, height)
        let maxSide = max(width, height)

        // 同时满足短边、长边限制，并且不放大
        let scale = min(
            1.0,
            maxShortSide / minSide,
            maxLongSide / maxSide
        )

        return CGSize(
            width: (width * scale).rounded(),
            height: (height * scale).rounded()
        )
    }

    // MARK: - 2. 按指定尺寸等比缩放

    /// 将 NSImage 缩放到指定像素尺寸（使用 CG 重绘）
    func resized(to targetSize: CGSize) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let targetWidth = Int(targetSize.width)
        let targetHeight = Int(targetSize.height)

        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        guard let scaledCGImage = ctx.makeImage() else {
            return nil
        }

        return NSImage(
            cgImage: scaledCGImage,
            size: targetSize   // 这里的 size 不用于像素计算，只是 NSImage 的逻辑尺寸
        )
    }

    // MARK: - 3. 在给定最大体积下做 JPEG 压缩

    /// 在给定最大字节数下，尝试不同 compression，返回满足限制的 JPEG Data
    func jpegData(
        maxBytes: Int,
        initialCompression: CGFloat = 0.9,
        minCompression: CGFloat = 0.3,
        step: CGFloat = 0.1
    ) -> Data? {
        var compression = initialCompression

        while compression >= minCompression {
            if let data = jpegData(compression: compression),
               data.count <= maxBytes {
                return data
            }
            compression -= step
        }

        // 兜底：返回最小压缩质量（即使略超）
        return jpegData(compression: minCompression)
    }

    // MARK: - 4. 总入口：符合 OpenAI 要求的 Data

    /// 按 OpenAI 尺寸 + 体积限制生成 JPEG Data
    func openAIReadyImageData(
        maxShortSide: CGFloat = 768,
        maxLongSide: CGFloat = 2000,
        maxBytes: Int = 2 * 1024 * 1024
    ) -> Data? {
        // 1. 计算目标尺寸
        guard let targetSize = scaledSizeForOpenAI(
            maxShortSide: maxShortSide,
            maxLongSide: maxLongSide
        ) else {
            return nil
        }

        // 2. 缩放
        guard let resizedImage = resized(to: targetSize) else {
            return nil
        }

        // 3. 按体积限制压缩
        return resizedImage.jpegData(maxBytes: maxBytes)
    }
}
