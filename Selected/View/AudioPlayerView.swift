//
//  Audio.swift
//  Selected
//
//  Created by sake on 2024/6/10.
//

import Foundation
import SwiftUI


struct AudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var sliderValue: Double = 0.0
    
    let audio: Data
    
    var body: some View {
        HStack {
            Text(String(format: "%02d:%02d", ((Int)((audioPlayer.currentTime))) / 60, ((Int)((audioPlayer.currentTime))) % 60))
                .foregroundColor(Color.black.opacity(0.6))
                .font(.custom("Quicksand Regular", size: 14))
                .frame(width: 40)
            
            Slider(value: $sliderValue, in: 0...audioPlayer.duration) { isEditing in
                if !isEditing {
                    audioPlayer.seek(to: sliderValue)
                }
            }
            .padding()
            .onChange(of: audioPlayer.currentTime) { newValue in
                sliderValue = newValue
            }.frame(width: 300)
            
            BarButton(icon: audioPlayer.isPlaying ? "symbol:pause.fill" : "symbol:play.fill", title: "" , clicked: {
                $isLoading in
                audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
            })
            
            BarButton(icon: "symbol:square.and.arrow.down", title: "" , clicked: {
                $isLoading in
                audioPlayer.saveCurrentState()
            })
            Spacer()
        }
        .onAppear() {
            audioPlayer.loadAudio(data: audio)
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
    
    func loadAudio(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = self.player?.currentTime ?? 0.0
            self.isPlaying =  self.player?.isPlaying ?? false
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
