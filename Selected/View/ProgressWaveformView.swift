import SwiftUI
import DSWaveformImageViews

struct ProgressWaveformView: View {
    let audioURL: URL
    let progress: Binding<Double>

    var body: some View {
        GeometryReader { geometry in
            WaveformView(audioURL: audioURL) { shape in
                ZStack {
                    shape.fill(AppTheme.border)
                    shape.fill(AppTheme.accent).mask(alignment: .leading) {
                        Rectangle().frame(width: geometry.size.width * progress.wrappedValue)
                    }
                }
            }
        }
    }
}
