//
//  Audio.swift
//  Selected
//
//  Created by sake on 2024/6/10.
//

import Foundation
import SwiftUI
import DSWaveformImageViews
import Defaults

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


import AVFoundation

class AudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0

    private var timer: Timer?

    func loadAudio(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            duration = player?.duration ?? 0.0
        } catch {
            print("Error loading audio file: \(error)")
        }
    }

    func play() {
        player?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.isPlaying =  self.player?.isPlaying ?? false
            if self.isPlaying {
                self.currentTime = self.player?.currentTime ?? 0.0
            } else {
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func save(_ audioURL: URL) {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDirectory = paths.first else{
            return
        }
        let unixTime = Int(Date().timeIntervalSince1970)
        let tts = documentsDirectory.appending(path: "Selected/tts-\(unixTime).mp3")
        do{
            try FileManager.default.createDirectory(at: tts.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: audioURL, to: tts)
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tts.deletingLastPathComponent().path)
        } catch {
            NSLog("move failed \(error)")
        }
    }
}


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
                    .fill(Color.white)
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
