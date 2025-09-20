//
//  WhisperTranscriber.swift
//  PersonalConversationalBot
//
//  Created by karan dhiman on 20/09/2025.
//

import Foundation

@_silgen_name("transcribe_from_wav")
func transcribe_from_wav(_ modelPath: UnsafePointer<CChar>?, _ buffer: UnsafePointer<Int16>?, _ num_samples: Int32) -> UnsafePointer<CChar>?
