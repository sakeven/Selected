//
//  Audio.swift
//  Selected
//
//  Created by sake on 2024/6/10.
//

import Foundation
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


struct AudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var sliderValue: Double = 0.0
    
    let audioURL: URL
    @State var progress: Double = 0
    
    var body: some View {
        HStack {
            Text(String(format: "%02d:%02d", ((Int)((audioPlayer.currentTime))) / 60, ((Int)((audioPlayer.currentTime))) % 60))
                .foregroundColor(Color.black.opacity(0.6))
                .font(.custom("Quicksand Regular", size: 14))
                .frame(width: 40).padding(.leading, 10)
        
            ZStack{
                ProgressWaveformView(audioURL: audioURL, progress: $progress).frame(width: 400)
                Slider(value: $sliderValue, in: 0...audioPlayer.duration) { isEditing in
                    if !isEditing {
                        audioPlayer.seek(to: sliderValue)
                    }
                }.foregroundColor(.clear).background(.clear).opacity(0.1)
                .controlSize(.mini).frame(width: 400)
                    .onChange(of: audioPlayer.currentTime) { newValue in
                        sliderValue = newValue
                        progress = sliderValue/audioPlayer.duration
                    }.frame(width: 300)
            }.frame(height: 30)
            
            Text(String(format: "%02d:%02d", ((Int)((audioPlayer.duration))) / 60, ((Int)((audioPlayer.duration))) % 60))
                .foregroundColor(Color.black.opacity(0.6))
                .font(.custom("Quicksand Regular", size: 14))
                .frame(width: 40)
            
            BarButton(icon: audioPlayer.isPlaying ? "symbol:pause.fill" : "symbol:play.fill", title: "" , clicked: {
                $isLoading in
                audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
            }).frame(height: 30).cornerRadius(5)
            
            BarButton(icon: "symbol:square.and.arrow.down", title: "" , clicked: {
                $isLoading in
                audioPlayer.saveCurrentState()
            }).frame(height: 30).cornerRadius(5)
            Spacer()
        }.frame(height: 50)
            .background(.white)
            .cornerRadius(5).fixedSize()
        .onAppear() {
            audioPlayer.loadAudio(url: audioURL)
            audioPlayer.play()
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
            // TODO: add AVAudioPlayerDelegate to be notified when a sound has finished playing
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = self.player?.currentTime ?? 0.0
            self.isPlaying =  self.player?.isPlaying ?? false
            if !self.isPlaying {
                stopTimer()
            }
//            NSLog("timer \(currentTime) \(isPlaying)")
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
    
    func saveCurrentState() {
        // Implement save logic here
    }
}
