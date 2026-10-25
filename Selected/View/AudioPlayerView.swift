import SwiftUI
import Defaults

struct AudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var sliderValue: Double = 0
    @State private var progress: Double = 0
    @State private var isSeeking = false

    let audioURL: URL

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
                Text("audio.title").font(.headline)
                Text(Defaults[.openAIVoice].rawValue)
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("audio.save", systemImage: "square.and.arrow.down") { audioPlayer.save(audioURL) }
                    .buttonStyle(AppIconButtonStyle())
                    .help("audio.save")
            }

            ProgressWaveformView(audioURL: audioURL, progress: $progress)
                .frame(height: 34)
                .accessibilityHidden(true)

            HStack(spacing: 12) {
                Button {
                    audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
                } label: {
                    Label(audioPlayer.isPlaying ? "audio.pause" : "audio.play", systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(AppButtonStyle(emphasis: .prominent))
                .help(audioPlayer.isPlaying ? "audio.pause" : "audio.play")

                Text(Duration.seconds(audioPlayer.currentTime).formatted(.time(pattern: .minuteSecond)))
                    .monospacedDigit().frame(width: 42)
                Slider(value: $sliderValue, in: 0...(audioPlayer.duration > 0 ? audioPlayer.duration : 1)) { editing in
                    isSeeking = editing
                    if !editing { audioPlayer.seek(to: sliderValue) }
                }
                .disabled(audioPlayer.duration == 0)
                .accessibilityLabel("audio.position")
                Text(Duration.seconds(audioPlayer.duration).formatted(.time(pattern: .minuteSecond)))
                    .monospacedDigit().frame(width: 42)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 600)
        .modifier(AppPanel())
        .onChange(of: audioPlayer.currentTime) { _, value in
            if !isSeeking { sliderValue = value }
            progress = audioPlayer.duration > 0 ? value / audioPlayer.duration : 0
        }
        .onAppear {
            audioPlayer.loadAudio(url: audioURL)
            audioPlayer.play()
        }
    }
}
