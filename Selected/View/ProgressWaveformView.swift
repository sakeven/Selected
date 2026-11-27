import SwiftUI
import DSWaveformImage
import DSWaveformImageViews

struct ProgressWaveformView: View {
    let audioURL: URL
    let currentTime: TimeInterval
    let duration: TimeInterval
    let seek: (TimeInterval) -> Void
    @State private var samples: [Float] = []
    @State private var hovered = false
    @FocusState private var focused: Bool
    @Environment(\.displayScale) private var displayScale

    private var progress: Double { duration > 0 ? currentTime / duration : 0 }

    var body: some View {
        GeometryReader { geometry in
            let shape = WaveformShape(samples: samples, configuration: .init(scale: displayScale))
            ZStack(alignment: .leading) {
                shape.fill(.primary.opacity(0.12))
                shape.fill(AppTheme.primaryAction).mask(alignment: .leading) {
                    Rectangle().frame(width: geometry.size.width * progress)
                }
                Rectangle()
                    .fill(AppTheme.primaryAction.opacity(hovered || focused ? 0.9 : 0.45))
                    .frame(width: 1, height: hovered || focused ? 30 : 22)
                    .offset(x: min(geometry.size.width - 1, geometry.size.width * progress))
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    focused = true
                    seek(min(max(value.location.x / geometry.size.width, 0), 1) * duration)
                })
            .task(id: audioURL) {
                samples = []
                do {
                    let result = try await WaveformAnalyzer().samples(fromAudioAt: audioURL, count: Int(geometry.size.width * displayScale))
                    try Task.checkCancellation()
                    samples = result
                } catch {
                    if !Task.isCancelled { logger.error("Waveform analysis failed: \(error)") }
                }
            }
        }
        .onHover { hovered = $0 }
        .focusable()
        .focused($focused)
        .onKeyPress(.leftArrow) { seek(currentTime - 5); return .handled }
        .onKeyPress(.rightArrow) { seek(currentTime + 5); return .handled }
        .help("audio.seekHint")
        .accessibilityRepresentation {
            Slider(value: Binding(get: { currentTime }, set: seek), in: 0...duration) {
                Text("audio.position")
            }
            .accessibilityValue(Duration.seconds(currentTime).formatted(.time(pattern: .minuteSecond)))
        }
    }
}
