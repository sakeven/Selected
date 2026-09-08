import SwiftUI
import DSWaveformImageViews

struct ProgressWaveformView: View {
    let audioURL: URL
    let progress: Binding<Double>

    var body: some View {
        GeometryReader { geometry in
            WaveformView(audioURL: audioURL) { shape in
                shape.fill(.clear)
                shape.fill(.blue).mask(alignment: .leading) {
                    Rectangle().frame(width: geometry.size.width * progress.wrappedValue)
                }
            }
        }
    }
}
