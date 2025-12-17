//
//  OCR.swift
//  Selected
//
//  Created by sake on 2024/4/10.
//

import Foundation
import Vision
import AppKit

func recognizeTextInImage(_ image: NSImage) -> String {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return ""
    }

    var str: String = ""
    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation],
              error == nil else {
            return
        }
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            str += topCandidate.string
        }
    }
    request.recognitionLevel = .accurate
    var recognitionLanguages = Set(Locale.preferredLanguages)
    recognitionLanguages.insert("en")
    request.recognitionLanguages = [String](recognitionLanguages)
    
    let handler = VNImageRequestHandler(cgImage: cgImage)
    do {
        try handler.perform([request])
        return str
    } catch {
        print("Error recognizing text: \(error)")
    }
    return ""
}
