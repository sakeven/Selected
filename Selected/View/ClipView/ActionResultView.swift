import SwiftUI

struct ActionResultView: View {
    @Bindable var session: ActionSession
    let onClose: () -> Void
    @State private var showOriginal = false
    @State private var showActions = false
    @State private var isPasting = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Picker("Content", selection: $showOriginal) {
                Text("Result").tag(false)
                Text("Original content").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                if showOriginal { original }
                else if session.isRunning {
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.small)
                        Text("Processing content…").font(.headline)
                        Text("You can switch apps while this runs.").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if session.completed && !session.output.isEmpty {
                    if session.request.output == .xshow {
                        TextEditor(text: $session.output)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(12)
                    } else {
                        ScrollView {
                            Text(session.output).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        }
                    }
                } else {
                    ContentUnavailableView(session.failed ? String(localized: "Run failed") : session.message,
                                           systemImage: session.failed ? "exclamationmark.bubble" : "doc.text",
                                           description: session.failed ? Text(session.message) : nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colorScheme == .dark ? Color.white.opacity(0.035) : .white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.blue.opacity(0.12)) }

            if !session.message.isEmpty && (session.completed || session.isRunning || showOriginal) {
                Text(session.message).font(.caption).foregroundStyle(session.failed ? .red : .secondary)
                    .lineLimit(3).textSelection(.enabled)
            }
            controls
        }
        .padding(20)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 410, idealHeight: 480)
        .background(colorScheme == .dark ? Color(red: 0.10, green: 0.12, blue: 0.16) : Color(red: 0.95, green: 0.97, blue: 1))
        .tint(.blue)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars").font(.title3).foregroundStyle(.blue)
                .frame(width: 38, height: 38).background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(session.request.title).font(.headline).lineLimit(1)
                if session.request.output == .xshow, let app = session.target.application {
                    HStack(spacing: 5) {
                        if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 14, height: 14) }
                        Text("Paste destination: \(session.target.name)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 8)
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly).buttonStyle(.plain).padding(8).keyboardShortcut(.cancelAction)
        }
    }

    private var original: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let data = session.originalContent?.images.first, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                        .accessibilityLabel("Original content")
                }
                Text(session.original.context.Text.isEmpty ? String(localized: "Attachment input") : session.original.context.Text)
                    .textSelection(.enabled)
                if session.original.hasAttachment {
                    Label("The original attachment is retained for retry.", systemImage: "paperclip").foregroundStyle(.secondary)
                }
                if let reference = session.original.reference {
                    Divider()
                    Label("Clipboard reference", systemImage: "clipboard").font(.headline).foregroundStyle(.blue)
                    Text(reference).textSelection(.enabled)
                }
                if session.input.context.Text != session.original.context.Text {
                    Divider()
                    Label("Input for this step", systemImage: "arrow.right.circle").font(.headline).foregroundStyle(.blue)
                    Text(session.input.context.Text).textSelection(.enabled)
                    Button("Copy this step's input", systemImage: "doc.on.doc") { copyText(session.input.context.Text) }
                }
                Button("Copy original text", systemImage: "doc.on.doc") { copyText(session.original.context.Text) }
                    .disabled(session.original.context.Text.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if session.isRunning {
                Button("Cancel", systemImage: "stop.circle") { session.cancel() }
            } else {
                Button("Retry", systemImage: "arrow.clockwise") { showOriginal = false; session.run() }
                if session.completed && !session.output.isEmpty {
                    Button("Next action", systemImage: "wand.and.stars") { showActions = true }
                        .popover(isPresented: $showActions) {
                            ContentActionPicker(input: session.input.replacingText(session.output)) { request in
                                showActions = false
                                onClose()
                                request.perform(input: session.input.replacingText(session.output), target: session.target,
                                                original: session.original, originalContent: session.originalContent)
                            }
                        }
                    Menu {
                        Button("Continue in chat", systemImage: "bubble.left.and.text.bubble.right") { session.continueChat() }
                        if session.request.output == .xshow && session.target.canReplace {
                            Button("Paste at current cursor") { paste(replacing: false) }
                        }
                        if session.request.output == .xshow && session.canRestore {
                            Button("Restore original selection") { Task { await session.restore() } }
                        }
                    } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More actions")
                }
            }
            Spacer(minLength: 0)
            if session.completed && !session.output.isEmpty && !session.isRunning {
                Button("Copy", systemImage: "doc.on.doc") { session.copy() }.keyboardShortcut("c", modifiers: [.command, .shift])
                if session.request.output == .xshow {
                    Button(session.target.canReplace ? String(localized: "Replace original selection") : String(localized: "Paste"), systemImage: "return") {
                        paste(replacing: session.target.canReplace)
                    }
                        .buttonStyle(SettingsButtonStyle(emphasis: .primary))
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!session.target.isAvailable || isPasting)
                        .help(String(localized: "Paste to \(session.target.name)"))
                }
            }
        }
        .buttonStyle(SettingsButtonStyle())
        .controlSize(.regular)
        .disabled(isPasting)
    }

    private func paste(replacing: Bool) {
        isPasting = true
        Task {
            await session.paste(replacing: replacing)
            isPasting = false
        }
    }
}
