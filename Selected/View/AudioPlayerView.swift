import SwiftUI

struct AudioPlayerView: View {
    @Bindable var session: SpeechSession
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text(session.excerpt)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38, alignment: .topLeading)
                .help(session.text)

            HStack(spacing: 16) {
                Button(action: primaryAction) {
                    Image(systemName: primarySymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .contentShape(.circle)
                }
                .buttonStyle(SpeechPlaybackButtonStyle())
                .accessibilityLabel(primaryLabel)
                .help(primaryLabel)
                .keyboardShortcut(.space, modifiers: [])
                playbackContent
            }
            .frame(height: 52)
        }
        .padding(18)
        .frame(width: 440)
        .modifier(AppPanel())
        .onExitCommand(perform: onClose)
        .alert("audio.saveFailed", isPresented: Binding(get: { session.saveError != nil }, set: { if !$0 { session.saveError = nil } })) {
            Button("OK", role: .cancel) { session.saveError = nil }
        } message: {
            Text(session.saveError ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            Text("audio.title")
                .font(.system(size: 12, weight: .semibold))
            Text(verbatim: "·").foregroundStyle(.tertiary)
            Text(session.voice)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                if let savedURL = session.savedURL {
                    NSWorkspace.shared.activateFileViewerSelecting([savedURL])
                } else {
                    session.save()
                }
            } label: {
                Label(session.savedURL == nil ? "audio.save" : "audio.showSaved", systemImage: session.savedURL == nil ? "square.and.arrow.down" : "checkmark")
            }
            .disabled(session.audioURL == nil)
            .help(session.savedURL == nil ? "audio.save" : "audio.showSaved")
            Button("audio.close", systemImage: "xmark", action: onClose)
                .help("audio.close")
        }
        .buttonStyle(AppIconButtonStyle())
    }

    @ViewBuilder private var playbackContent: some View {
        if session.phase == .failed {
            VStack(alignment: .leading, spacing: 3) {
                Text("audio.failed").font(.callout.weight(.medium))
                Text(session.errorMessage ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .help(session.errorMessage ?? "")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else if let audioURL = session.audioURL {
            VStack(spacing: 4) {
                ProgressWaveformView(audioURL: audioURL, currentTime: session.currentTime, duration: session.duration, seek: session.seek)
                    .frame(height: 32)
                HStack {
                    Text(Duration.seconds(session.currentTime).formatted(.time(pattern: .minuteSecond)))
                    Spacer()
                    Text(session.savedURL == nil ? statusLabel : "audio.saved")
                    Spacer()
                    Text(Duration.seconds(session.duration).formatted(.time(pattern: .minuteSecond)))
                }
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    if session.phase == .generating {
                        ProgressView().controlSize(.mini)
                    }
                    Text(statusLabel).font(.callout.weight(.medium))
                }
                Text(session.phase == .generating ? "audio.autoplayHint" : "audio.systemHint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private var statusLabel: LocalizedStringKey {
        switch session.phase {
        case .idle: "audio.title"
        case .generating: "audio.generating"
        case .playing: "audio.playing"
        case .paused: "audio.paused"
        case .finished: "audio.finished"
        case .failed: "audio.failed"
        }
    }

    private var primaryLabel: LocalizedStringKey {
        switch session.phase {
        case .generating: "audio.cancel"
        case .playing: "audio.pause"
        case .failed: "audio.retry"
        case .finished: "audio.replay"
        case .paused, .idle: "audio.play"
        }
    }

    private var primarySymbol: String {
        switch session.phase {
        case .generating: "stop.fill"
        case .playing: "pause.fill"
        case .failed: "arrow.clockwise"
        case .finished: "arrow.counterclockwise"
        case .paused, .idle: "play.fill"
        }
    }

    private func primaryAction() {
        if session.phase == .generating { onClose() }
        else { session.togglePlayback() }
    }
}

private struct SpeechPlaybackButtonStyle: ButtonStyle {
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.onPrimaryAction)
            .background(AppTheme.primaryAction.opacity(configuration.isPressed ? 0.75 : hovered ? 0.9 : 1), in: .circle)
            .onHover { hovered = $0 }
    }
}
