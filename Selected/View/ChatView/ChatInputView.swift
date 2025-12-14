//
//  ChatInputView.swift
//  Selected
//
//  Created by sake on 14/12/25.
//


import SwiftUI
import PhotosUI

struct ChatInputView: View {
    var viewModel: MessageViewModel
    @State private var newText: String = ""
    @State private var task: Task<Void, Never>? = nil
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var pickedImages: [PickedImage] = []
    @State private var showMissingTextAlert = false
    @State private var showFileImporter = false

    var onCancel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !pickedImages.isEmpty {
                previewHeader
            }

            if #available(macOS 14.0, *) {
                ZStack(alignment: .leading) {
                    if newText.isEmpty {
                        Text("Press cmd+enter to send new message")
                            .foregroundStyle(.secondary)
                            .padding(4)
                    }
                    TextEditor(text: $newText)
                        .onKeyPress(.return, phases: .down) { keyPress in
                            guard keyPress.modifiers.contains(.command) else { return .ignored }
                            submitMessage()
                            return .handled
                        }
                        .opacity(newText.isEmpty ? 0.25 : 1)
                        .padding(10)
                }
                .frame(minHeight: 70)
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .onDisappear { task?.cancel() }
            } else {
                TextField("Press enter to send new message", text: $newText, axis: .vertical)
                    .lineLimit(3...)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onSubmit { submitMessage() }
                    .onDisappear { task?.cancel() }
            }

            HStack {
                PhotosPicker(selection: $selectedPickerItems,
                             maxSelectionCount: 5,
                             matching: .images) {
                    Label("Choose photos", systemImage: "photo.on.rectangle.angled")
                }.onChange(of: selectedPickerItems) { items in
                    loadImagesFromPhotosPicker(items)
                    selectedPickerItems = []
                }
                Button("Choose local photos", systemImage: "photo.badge.plus") {
                    showFileImporter = true
                }
                Spacer()
                if viewModel.inProgress {
                    Button("Stop", systemImage: "stop.circle" ) {
                        cancel()
                    }.foregroundStyle(.red)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
                case .success(let urls):
                    loadImagesFromFileImporter(urls)
                case .failure(let error):
                    print("Import failed: \(error)")
            }
        }
        .alert("Text content needs to be entered.", isPresented: $showMissingTextAlert) {}
    }

    func cancel() {
        task?.cancel()
        onCancel?()
    }

    func loadImagesFromFileImporter(_ urls: [URL]) {
        Task {
            var newImages = pickedImages
            for url in urls {
                if let data = try? Data(contentsOf: url),
                   let nsImage = NSImage(data: data),
                   let jpegData = nsImage.openAIReadyImageData() {
                    newImages.append(PickedImage(data: jpegData))
                }
            }
            await MainActor.run {
                pickedImages = newImages
            }
        }
    }

    func loadImagesFromPhotosPicker(_ items: [PhotosPickerItem]) {
        Task {
            var newImages = pickedImages
            for item in items {
                if
                    let rawData = try? await item.loadTransferable(type: Data.self),
                    let nsImage = NSImage(data: rawData),
                    let jpegData = nsImage.openAIReadyImageData(){
                    newImages.append(PickedImage(data: jpegData))
                }
            }
            await MainActor.run {
                pickedImages = newImages
            }
        }
    }

    func submitMessage() {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showMissingTextAlert = true
            return
        }

        let attachments = pickedImages.map(\.data)

        newText = ""
        pickedImages.removeAll()
        selectedPickerItems.removeAll()

        task = Task {
            print("attachments: \(attachments.count)")
            await viewModel.submit(message: .init(text: text, images: attachments))
        }
    }

    private var previewHeader: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(pickedImages) { image in
                    ZStack(alignment: .topTrailing) {
                        if let nsImage = NSImage(data: image.data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Color.gray.frame(width: 64, height: 64)
                        }
                        Button {
                            removePickedImage(image)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
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
