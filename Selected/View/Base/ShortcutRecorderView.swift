//
//  ShortcutRecorderView.swift
//  Selected
//
//  Created by sake on 2024/4/21.
//

import SwiftUI
import ShortcutRecorder

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    
    func makeNSView(context: Context) -> RecorderControl {
        let recorder = RecorderControl()
        return recorder
    }
    
    func updateNSView(_ nsView: RecorderControl, context: Context) {
        nsView.objectValue = shortcut
        nsView.delegate = context.coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, RecorderControlDelegate {
        var parent: ShortcutRecorderView
        
        init(_ recorderWrapper: ShortcutRecorderView) {
            self.parent = recorderWrapper
        }
        
        func shortcutRecorderDidEndRecording(_ recorder: RecorderControl) {
            if let objectValue = recorder.objectValue {
                parent.shortcut = objectValue
            }
        }
    }
}
