import SwiftUI
import Defaults

struct AudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var sliderValue: Double = 0.0

    let audioURL: URL
    @State var progress: Double = 0

    var body: some View {
        // Audio player card
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 16) {
                    HStack {
                        Text(String(format: "%02d:%02d", ((Int)((audioPlayer.currentTime))) / 60, ((Int)((audioPlayer.currentTime))) % 60))
                            .foregroundColor(Color.black.opacity(0.6))
                            .font(.custom("Quicksand Regular", size: 14))
                            .frame(width: 40).padding(.leading, 10)
                        ZStack{
                            ProgressWaveformView(audioURL: audioURL, progress: $progress).frame(width: 450)
                            Slider(value: $sliderValue, in: 0...audioPlayer.duration) { isEditing in
                                if !isEditing {
                                    audioPlayer.seek(to: sliderValue)
                                }
                            }.foregroundColor(.clear).background(.clear).opacity(0.1)
                                .controlSize(.mini).frame(width: 450)
                                .onChange(of: audioPlayer.currentTime) { newValue in
                                    sliderValue = newValue
                                    progress = sliderValue/audioPlayer.duration
                                }
                        }

                        Text(String(format: "%02d:%02d", ((Int)((audioPlayer.duration-audioPlayer.currentTime))) / 60, ((Int)((audioPlayer.duration-audioPlayer.currentTime))) % 60))
                            .foregroundColor(Color.black.opacity(0.6))
                            .font(.custom("Quicksand Regular", size: 14))
                            .frame(width: 40)
                    }.padding(.top, 15)

                    // Controls
                    HStack {
                        // Play/Pause button
                        Button(action: {
                            audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.8))
                                    .frame(width: 30, height: 30)

                                if audioPlayer.isPlaying {
                                    Image(systemName: "pause.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .bold))
                                } else {
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Download button
                        Button(action: {audioPlayer.save(audioURL)}) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 30, height: 30)

                                Image(systemName: "arrow.down")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()

                        // Info text
                        HStack(spacing: 5) {
                            Text(Defaults[.openAIVoice].rawValue)
                                .foregroundColor(.gray)

                            Text("·")
                                .foregroundColor(.gray)

                            Text(valueFormatter.string(from: NSNumber(value: audioPlayer.duration))!)
                                .foregroundColor(.gray)

                            Text("·")
                                .foregroundColor(.gray)

                            Text("1x")
                                .foregroundColor(.gray)

                            Text("·")
                                .foregroundColor(.gray)

                            Text("mp3")
                                .foregroundColor(.gray)

                            Text("·")
                                .foregroundColor(.gray)

                            HStack(spacing: 2) {
                                Text("Instructions")
                                    .foregroundColor(.gray)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)
                }
            }
        }.frame(width: 600, height: 150)
            .onAppear() {
                audioPlayer.loadAudio(url: audioURL)
                audioPlayer.play()
            }
    }
}
