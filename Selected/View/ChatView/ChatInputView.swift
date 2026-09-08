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
    @State private var attachmentSelection = ChatAttachments()
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
            if !attachmentSelection.files.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(attachmentSelection.files) { file in
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                Text(file.attachment.filename)
                                    .font(.callout)
                                    .lineLimit(1)
                                Button { attachmentSelection.files.removeAll { $0.id == file.id } } label: {
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
            if !attachmentSelection.images.isEmpty { previewHeader }
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
                    try attachmentSelection.append(content, filename: url.lastPathComponent, openAI: openAI)
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
                    try attachmentSelection.appendImage(jpegData, openAI: viewModel.usesOpenAIFileInputs)
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

        let attachments = attachmentSelection.images.map(\.data)
        let files = attachmentSelection.files.map(\.attachment)

        newText = ""
        attachmentSelection.images.removeAll()
        attachmentSelection.files.removeAll()
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
                ForEach(attachmentSelection.images) { image in
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

    private func removePickedImage(_ image: ChatAttachments.Image) {
        if let index = attachmentSelection.images.firstIndex(where: { $0.id == image.id }) {
            attachmentSelection.images.remove(at: index)
        }
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
