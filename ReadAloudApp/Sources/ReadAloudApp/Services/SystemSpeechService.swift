import Foundation
import AVFoundation

protocol SpeechSynthesizing {
    var isSpeaking: Bool { get }
    func speak(_ text: String, rate: Float)
    func speak(_ text: String, rate: Float, languageCode: String)
    func pause()
    func stop()
}

final class SystemSpeechService: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking: Bool = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = clampRate(rate)
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func speak(_ text: String, rate: Float, languageCode: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = clampRate(rate)
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func pause() {
        if synthesizer.isSpeaking {
            _ = synthesizer.pauseSpeaking(at: .immediate)
            isSpeaking = false
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    private func clampRate(_ rate: Float) -> Float {
        // AVSpeechUtteranceDefaultSpeechRate ~ 0.5; clamp to iOS bounds
        let minR = AVSpeechUtteranceMinimumSpeechRate
        let maxR = AVSpeechUtteranceMaximumSpeechRate
        // Map 0.5...2.0 around default rate
        let normalized = max(0.5, min(2.0, rate))
        return min(maxR, max(minR, AVSpeechUtteranceDefaultSpeechRate * normalized))
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}


