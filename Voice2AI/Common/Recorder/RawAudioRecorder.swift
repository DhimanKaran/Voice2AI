//
//  AudioRecorder.swift
//  Voice2AI
//
//  Created by karan dhiman on 20/09/2025.
//

import AVFoundation

final class RawAudioRecorder {
    private let audioEngine = AVAudioEngine()
    private var outputFileHandle: FileHandle?
    private var isRecording = false
    
    private let targetSampleRate: Double = 16000.0
    private let channels: AVAudioChannelCount = 1
    
    private let fileURL: URL
    
    private var converter: AVAudioConverter?
    private let outputFormat: AVAudioFormat
    
    init() {
        // Set file URL for raw audio
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent("recording.raw")
        
        // Define output format: 16kHz, mono, 16-bit integer PCM, interleaved
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: targetSampleRate, channels: channels, interleaved: true)!
    }
    
    func startRecording() throws {
        if isRecording { return }
        
        // Remove existing file if any
        try? FileManager.default.removeItem(at: fileURL)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        outputFileHandle = try FileHandle(forWritingTo: fileURL)
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // Setup converter from input native format to desired output format
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            
            guard let converter = self.converter else { return }
            
            // Prepare buffer for converted audio
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.outputFormat, frameCapacity: AVAudioFrameCount(self.outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)) else {
                print("Failed to create converted buffer")
                return
            }
            
            // Convert audio buffer to target format
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
            
            if status == .error || error != nil {
                print("Audio conversion error: \(String(describing: error))")
                return
            }
            
            // Write converted Int16 samples to file
            guard let int16ChannelData = convertedBuffer.int16ChannelData else {
                print("Converted buffer has no int16 data")
                return
            }
            
            let frameLength = Int(convertedBuffer.frameLength)
            let data = Data(bytes: int16ChannelData[0], count: frameLength * MemoryLayout<Int16>.size)
            
            do {
                try self.outputFileHandle?.write(contentsOf: data)
            } catch {
                print("Error writing audio data: \(error)")
            }
        }
        
        try audioEngine.start()
        isRecording = true
        
        print("Started recording raw audio at \(fileURL.path)")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        do {
            try outputFileHandle?.close()
        } catch {
            print("Error closing file handle: \(error)")
        }
        
        outputFileHandle = nil
        isRecording = false
        
        print("Stopped recording. File saved to \(fileURL.path)")
    }
    
    func getRecordingURL() -> URL {
        return fileURL
    }
}
