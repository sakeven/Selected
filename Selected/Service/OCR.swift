//
//  OCR.swift
//  Selected
//
//  Created by sake on 2024/4/10.
//

import Foundation
import Vision
import AppKit

func recognizeTextInImage(_ image: NSImage) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return
    }
    
    print("recognizeTextInImage")
    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation],
              error == nil else {
            return
        }
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            print(topCandidate.string)
        }
    }
    request.recognitionLevel = .accurate
    var recognitionLanguages = Set( Locale.preferredLanguages)
    print("Preferred languages: \(recognitionLanguages)")
    recognitionLanguages.insert("en")
    request.recognitionLanguages = [String](recognitionLanguages)
    
    let handler = VNImageRequestHandler(cgImage: cgImage)
    do {
        try handler.perform([request])
    } catch {
        print("Error recognizing text: \(error)")
    }
    print("recognizeTextInImage end")
}
