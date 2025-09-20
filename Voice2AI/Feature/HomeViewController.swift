//
//  ViewController.swift
//  Voice2AI
//
//  Created by karan dhiman on 20/09/2025.
//

import UIKit

class HomeViewController: UIViewController {
    // MARK: - Constants
    private enum Constants {
        static let qwen = "Qwen"
        static let tinyLlama = "TinyLlama"
        static let gguf = "gguf"
        static let recording = "Recording..."
        static let record = "Record"
        static let prompt = "You're an assistant who helps with question now respond factually and concisely to the following user question below. Provide only precise and single conversational reply without repetition."
    }

    // MARK: - IBOutlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var recordButton: UIButton!
    
    // MARK: - Properties
    private var progressOverlay: UIView?
    private let recorder = RawAudioRecorder()
    private var llama: LlamaContext?
    private var resource: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        segmentedControl.selectedSegmentIndex = 1
        resource = Constants.qwen
    }

    // MARK: - IBActions
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        resource = sender.selectedSegmentIndex == 0 ? Constants.tinyLlama : Constants.qwen
    }

    @IBAction func recordButtonDidTap(_ sender: UIButton) {
        sender.isEnabled = false
        sender.setTitle(Constants.recording, for: .normal)
        sender.setTitleColor(.systemRed, for: .disabled)

        do {
            try recorder.startRecording()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    @IBAction func stopButtonDidTap(_ sender: Any) {
        // Restore Record button state
        recordButton.setTitle(Constants.record, for: .normal)
        recordButton.setTitleColor(.systemBlue, for: .normal)
        recordButton.isEnabled = true

        // Show progress overlay and perform work asynchronously
        showProgress(completion: {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                recorder.stopRecording()
                transcribeAudio()
            }
        })
    }

    // MARK: - Audio & LLM Processing
    private func transcribeAudio() {
        let rawAudioURL = recorder.getRecordingURL()
        guard let data = try? Data(contentsOf: rawAudioURL) else {
            print("Failed to load raw audio")
            DispatchQueue.main.async { self.hideProgress() }
            return
        }
        let result = WhisperTranscriptionManager.shared.transcribe(from: data)
        Task { await testLlama(text: result) }
    }

    // MARK: - Llama Context Initialization
    @MainActor
    func testLlama(text: String) async {
        // Creating a new Llama instance for each context because we are forcefully returning text
        // from llama.cpp if it is repeating. Reusing the same context produce inconsistent or unexpected behavior,
        // so instantiating a fresh model ensures the output is consistent and deterministic in our case.
        guard let llama = createLlamaContext() else {
            print("Llama context not initialized")
            DispatchQueue.main.async {
                self.hideProgress()
            }
            return
        }
        
        // Run prompt
        await llama.completion_init(text: createPromptWithQuestion(text: text))
        var response = ""
        while await !llama.is_done {
            let token = await llama.completion_loop()
            response += token
        }

        // Remove repeated fragments from output
        let finalResponse = removeRepetitions(from: response)
        DispatchQueue.main.async { [weak self] in
            self?.textView.text = finalResponse
            self?.hideProgress()
        }
    }
}

// MARK: - Progress Overlay
extension HomeViewController {
    private func showProgress(completion: (() -> Void)? = nil) {
        if progressOverlay != nil { return }
        
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let activity = UIActivityIndicatorView(style: .large)
        activity.center = overlay.center
        activity.startAnimating()
        overlay.addSubview(activity)
        
        view.addSubview(overlay)
        progressOverlay = overlay
        completion?()
    }

    private func hideProgress() {
        progressOverlay?.removeFromSuperview()
        progressOverlay = nil
    }
}

// MARK: - Llama Context & Prompt Helpers
extension HomeViewController {
    private func createLlamaContext() -> LlamaContext? {
        guard let resource else { return nil }
        do {
            let modelPath = Bundle.main.path(forResource: resource, ofType: Constants.gguf)!
            llama = try LlamaContext.create_context(path: modelPath)
            return llama
        } catch {
            print("context creation failed: \(error)")
            print("Make sure there is model at path Voice2AI/Dependencies/Llama/Model!")
        }
        return nil
    }

    private func createPromptWithQuestion(text: String) -> String {
        return """
            \(Constants.prompt)
            <user>
            \(text)
            </user>
            <assistant>
            """
    }

    // MARK: - Text Cleanup
    private func removeRepetitions(from text: String) -> String {
        var result = ""
        var seenFragments = Set<String>()
        
        // Split by punctuation but keep punctuation
        let separators: Set<Character> = [".", ",", "!", "<", "/", "|", ">"]
        var fragmentStart = text.startIndex
        
        func normalized(_ fragment: String) -> String {
            // Lowercase, remove punctuation & whitespace
            fragment.lowercased().filter { !$0.isPunctuation && !$0.isWhitespace }
        }
        
        var index = text.startIndex
        while index < text.endIndex {
            if separators.contains(text[index]) {
                let fragment = text[fragmentStart...index].trimmingCharacters(in: .whitespacesAndNewlines)
                if !fragment.isEmpty {
                    let norm = normalized(fragment)
                    var isRepeated = false
                    for seen in seenFragments {
                        if seen.contains(norm) || norm.contains(seen) {
                            isRepeated = true
                            break
                        }
                    }
                    if !isRepeated {
                        result += (result.isEmpty ? "" : " ") + fragment
                        seenFragments.insert(norm)
                    }
                }
                fragmentStart = text.index(after: index)
            }
            index = text.index(after: index)
        }
        
        // Add remaining fragment
        if fragmentStart < text.endIndex {
            let fragment = text[fragmentStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !fragment.isEmpty {
                let norm = normalized(fragment)
                var isRepeated = false
                for seen in seenFragments {
                    if seen.contains(norm) || norm.contains(seen) {
                        isRepeated = true
                        break
                    }
                }
                if !isRepeated {
                    result += (result.isEmpty ? "" : " ") + fragment
                }
            }
        }
        return result
    }
}

