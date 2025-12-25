//
//  SharingButton.swift
//  Selected
//
//  Created by sake on 2024/3/27.
//

import Foundation
import SwiftUI


// https://stackoverflow.com/a/60955909
struct SharingsPicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    var sharingItems: [Any] = []
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            let picker = NSSharingServicePicker(items: sharingItems)
            picker.delegate = context.coordinator
            
            // !! MUST BE CALLED IN ASYNC, otherwise blocks update
            DispatchQueue.main.async {
                picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }
    
    class Coordinator: NSObject, NSSharingServicePickerDelegate {
        let owner: SharingsPicker
        
        init(owner: SharingsPicker) {
            self.owner = owner
        }
        
        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            sharingServicePicker.delegate = nil   // << cleanup
            DispatchQueue.main.async {
                self.owner.isPresented = false        // << dismiss
            }
        }
    }
}


struct SharingButton: View {
    @EnvironmentObject var model: ShowingSharingPickerModel

    var message: String
    var body: some View {
        BarButton(icon: "symbol:square.and.arrow.up", title: "share", clicked: {
            _ in
            model.showing = !model.showing
        })
        .background(SharingsPicker(isPresented: $model.showing, sharingItems: [message]))
    }
}


class ShowingSharingPickerModel: ObservableObject {
    @Published var showing: Bool = false
}
