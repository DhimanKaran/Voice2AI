//
//  WhisperTranscriber.swift
//  Voice2AI
//
//  Created by karan dhiman on 20/09/2025.
//

import Foundation

final class WhisperTranscriptionManager {
    
    static let shared = WhisperTranscriptionManager()
    
    private let modelPath: String?
    
    private init() {
        modelPath = Bundle.main.path(forResource: "ggml-base.en", ofType: "bin")
        if modelPath == nil {
            print("Failed to locate Whisper model file in bundle. Make sure model is included in the project bundle at path Dependencies/Whisper/ggml-base.en.bin and at Dependencies/Whisper/Model")
        }
    }
    
    /// Transcribe 16-bit PCM WAV audio from `Data`
    func transcribe(from data: Data) -> String {
        guard let modelPath = modelPath else {
            return "Model not loaded"
        }
        
        // Ensure data is properly aligned and valid
        let result = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String in
            guard let int16Ptr = ptr.bindMemory(to: Int16.self).baseAddress else {
                return "Invalid audio data"
            }
            
            let count = data.count / MemoryLayout<Int16>.stride
            
            guard let cResult = transcribe_from_wav(modelPath, int16Ptr, Int32(count)) else {
                return "Transcription failed"
            }
            
            return String(cString: cResult)
        }
        
        return result
    }
}
