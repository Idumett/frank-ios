import Foundation

enum VoiceTurnResult: Equatable, Sendable {
    case speechStarted
    case sent
    case noSpeech
    case failed(String)
}

@MainActor
final class VoiceTurnRecorder {
    private let microphone: any MicrophoneCapturing
    private let sendAudio: @Sendable (Data) async throws -> Void
    private let settings: VoiceActivityDetector.Settings
    private var detector: VoiceActivityDetector
    private var buffer = TurnAudioBuffer()
    private var finished = false

    var onResult: ((VoiceTurnResult) -> Void)?

    init(
        microphone: any MicrophoneCapturing,
        settings: VoiceActivityDetector.Settings = .init(),
        sendAudio: @escaping @Sendable (Data) async throws -> Void
    ) {
        self.microphone = microphone
        self.settings = settings
        detector = VoiceActivityDetector(settings: settings)
        self.sendAudio = sendAudio
    }

    func start() async {
        guard await microphone.requestPermission() else {
            onResult?(.failed("Microphone permission is needed to hear you."))
            return
        }
        detector = VoiceActivityDetector(settings: settings)
        buffer.reset()
        finished = false
        do {
            try microphone.start { [weak self] chunk in
                Task { @MainActor in self?.receive(chunk) }
            }
        } catch {
            onResult?(.failed("Frank could not start the microphone."))
        }
    }

    func cancel() {
        finished = true
        microphone.stop()
        buffer.reset()
    }

    private func receive(_ chunk: CapturedAudioChunk) {
        guard !finished else { return }
        buffer.append(chunk)
        switch detector.process(chunk) {
        case .speechStarted:
            onResult?(.speechStarted)
        case .speechEnded, .maximumDurationReached:
            finishAndSend()
        case .noSpeech:
            finished = true
            microphone.stop()
            onResult?(.noSpeech)
        case .listening:
            break
        }
    }

    private func finishAndSend() {
        guard !finished else { return }
        finished = true
        microphone.stop()
        guard let wav = WavEncoder.encode(buffer.chunks) else {
            onResult?(.noSpeech)
            return
        }
        Task {
            do {
                try await sendAudio(wav)
                onResult?(.sent)
            } catch {
                onResult?(.failed("Frank could not send that recording."))
            }
        }
    }
}
