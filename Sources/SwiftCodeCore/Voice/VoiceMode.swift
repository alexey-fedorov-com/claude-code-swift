/// VoiceMode — voice input types and state machine.
///
/// Feature flag VOICE_MODE is enabled. Real audio capture requires CoreAudio
/// and a speech-to-text backend (Whisper / Apple STT). Those are stubbed here
/// pending OS-specific integration work.
///
/// Mirrors `src/utils/voiceMode.ts` and `src/components/VoiceInput.tsx`.

import Foundation

// MARK: - VoiceModeState

public enum VoiceModeState: Equatable, Sendable {
    /// Voice mode is disabled (feature flag off or user opt-out).
    case disabled
    /// Ready to record — waiting for user to hold the key.
    case idle
    /// Actively capturing audio from the microphone.
    case recording
    /// Audio captured; waiting for transcription result.
    case transcribing
    /// Transcription complete; text is in the `result` field.
    case done(transcript: String)
    /// An error occurred during capture or transcription.
    case error(VoiceError)
}

// MARK: - VoiceError

public enum VoiceError: Error, Equatable, Sendable {
    /// Microphone access was denied by the user.
    case microphonePermissionDenied
    /// No microphone hardware was found.
    case noMicrophoneAvailable
    /// The STT backend returned an error.
    case transcriptionFailed(reason: String)
    /// Audio capture or STT is not yet implemented on this platform.
    case notImplemented
}

// MARK: - VoiceCommand

/// User-facing voice commands.
public enum VoiceCommand: Equatable, Sendable {
    /// Begin recording (hold-to-talk activation).
    case startRecording
    /// Stop recording and submit for transcription.
    case stopRecording
    /// Abort recording without submitting.
    case cancel
    /// Toggle continuous voice mode on/off.
    case toggleContinuous
}

// MARK: - VoiceInputMode

public enum VoiceInputMode: String, Codable, Equatable, Sendable {
    /// Push-to-talk: hold a key to record.
    case holdToTalk
    /// Continuous: always listening; silence detection stops the utterance.
    case continuous
}

// MARK: - VoiceConfiguration

public struct VoiceConfiguration: Codable, Equatable, Sendable {
    public var inputMode: VoiceInputMode
    /// Language hint for the STT backend (BCP-47, e.g. "en-US").
    public var language: String
    /// Silence duration in seconds before auto-stopping in continuous mode.
    public var silenceThreshold: Double
    /// Whether to insert text as-is (true) or route through the normal input field (false).
    public var insertDirectly: Bool

    public init(
        inputMode: VoiceInputMode = .holdToTalk,
        language: String = "en-US",
        silenceThreshold: Double = 1.5,
        insertDirectly: Bool = false
    ) {
        self.inputMode = inputMode
        self.language = language
        self.silenceThreshold = silenceThreshold
        self.insertDirectly = insertDirectly
    }
}

// MARK: - VoiceService protocol

/// Platform-level voice capture + transcription.
/// The macOS implementation would use AVAudioEngine + Apple STT or Whisper.
public protocol VoiceService: Sendable {
    var state: VoiceModeState { get async }
    func start(configuration: VoiceConfiguration) async throws
    func stop() async throws -> String     // returns transcript
    func cancel() async
}

// MARK: - StubVoiceService

/// Stub — always throws `.notImplemented`. Swap in a real AVAudioEngine
/// implementation when audio pipeline is built.
public struct StubVoiceService: VoiceService {
    public init() {}

    public var state: VoiceModeState { get async { .disabled } }

    public func start(configuration: VoiceConfiguration) async throws {
        // TODO: request microphone permission via AVAudioSession / AVCaptureDevice
        // TODO: start AVAudioEngine tap and stream PCM frames to STT
        throw VoiceError.notImplemented
    }

    public func stop() async throws -> String {
        // TODO: flush audio buffer to STT backend, await transcript
        throw VoiceError.notImplemented
    }

    public func cancel() async {
        // TODO: stop audio engine, discard buffer
    }
}
