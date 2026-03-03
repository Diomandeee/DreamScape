import AVFoundation
import Combine
import ComposableArchitecture

// MARK: - Audio Layer Manager

/// Manages ambient sound playback and text-to-speech narration for immersive sessions.
/// Extracted from Serenity Soother's AudioPlayerService, adapted as a TCA dependency.
@DependencyClient
struct AudioLayerManager: Sendable {
    var playAmbient: @Sendable (AmbientSound) async -> Void
    var stopAmbient: @Sendable () async -> Void
    var setAmbientVolume: @Sendable (Float) async -> Void
    var speakNarration: @Sendable (String) async -> Void
    var stopNarration: @Sendable () async -> Void
    var pauseAll: @Sendable () async -> Void
    var resumeAll: @Sendable () async -> Void
    var stopAll: @Sendable () async -> Void
}

extension AudioLayerManager: DependencyKey {
    static let liveValue: AudioLayerManager = {
        let engine = AudioEngine()

        return AudioLayerManager(
            playAmbient: { sound in
                await engine.playAmbient(sound)
            },
            stopAmbient: {
                await engine.stopAmbient()
            },
            setAmbientVolume: { volume in
                await engine.setAmbientVolume(volume)
            },
            speakNarration: { text in
                await engine.speakNarration(text)
            },
            stopNarration: {
                await engine.stopNarration()
            },
            pauseAll: {
                await engine.pauseAll()
            },
            resumeAll: {
                await engine.resumeAll()
            },
            stopAll: {
                await engine.stopAll()
            }
        )
    }()

    static let testValue = AudioLayerManager()
}

extension DependencyValues {
    var audioLayer: AudioLayerManager {
        get { self[AudioLayerManager.self] }
        set { self[AudioLayerManager.self] = newValue }
    }
}

// MARK: - Audio Engine (Actor)

/// Thread-safe audio engine that manages AVAudioPlayer instances and speech synthesis.
private actor AudioEngine {
    private var ambientPlayer: AVAudioPlayer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var ambientVolume: Float = 0.5

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers, .duckOthers]
            )
            try session.setActive(true)
        } catch {
            print("[AudioEngine] Failed to setup audio session: \(error)")
        }
        #endif
    }

    // MARK: - Ambient

    func playAmbient(_ sound: AmbientSound) {
        stopAmbientSync()

        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: "mp3") else {
            print("[AudioEngine] Ambient sound not found: \(sound.fileName)")
            return
        }

        do {
            ambientPlayer = try AVAudioPlayer(contentsOf: url)
            ambientPlayer?.numberOfLoops = -1 // Loop indefinitely
            ambientPlayer?.volume = ambientVolume
            ambientPlayer?.prepareToPlay()
            ambientPlayer?.play()
        } catch {
            print("[AudioEngine] Failed to play ambient: \(error)")
        }
    }

    func stopAmbient() {
        stopAmbientSync()
    }

    private func stopAmbientSync() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func setAmbientVolume(_ volume: Float) {
        ambientVolume = volume
        ambientPlayer?.volume = volume
    }

    // MARK: - Narration (TTS)

    func speakNarration(_ text: String) {
        speechSynthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.38
        utterance.pitchMultiplier = 0.9
        utterance.volume = 0.85
        utterance.preUtteranceDelay = 0.5
        utterance.postUtteranceDelay = 1.0

        // Prefer a soothing enhanced voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let preferredIds = [
            "com.apple.voice.enhanced.en-US.Samantha",
            "com.apple.voice.enhanced.en-GB.Kate",
            "com.apple.ttsbundle.Samantha-compact"
        ]

        for id in preferredIds {
            if let voice = voices.first(where: { $0.identifier == id }) {
                utterance.voice = voice
                break
            }
        }

        if utterance.voice == nil {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        speechSynthesizer.speak(utterance)
    }

    func stopNarration() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Global Controls

    func pauseAll() {
        ambientPlayer?.pause()
        speechSynthesizer.pauseSpeaking(at: .word)
    }

    func resumeAll() {
        ambientPlayer?.play()
        speechSynthesizer.continueSpeaking()
    }

    func stopAll() {
        stopAmbientSync()
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}
