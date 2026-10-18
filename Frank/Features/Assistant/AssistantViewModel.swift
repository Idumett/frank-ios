import Combine
import Foundation

@MainActor
final class AssistantViewModel: ObservableObject {
    @Published private(set) var state: AssistantState = .ready
    @Published private(set) var detail = "Tap the button and speak naturally."
    @Published private(set) var transcript = ""

    private let session: AssistantSession?
    private let audioPlayer: (any ResponseAudioPlaying)?
    private var recorder: VoiceTurnRecorder?
    private var eventTask: Task<Void, Never>?

    init(
        session: AssistantSession? = nil,
        microphone: (any MicrophoneCapturing)? = nil,
        audioPlayer: (any ResponseAudioPlaying)? = nil
    ) {
        self.session = session
        self.audioPlayer = audioPlayer
        if let session, let microphone {
            recorder = VoiceTurnRecorder(
                microphone: microphone,
                settings: .init(maximumDuration: 12)
            ) { data in
                try await session.sendAudio(data)
            }
            recorder?.onResult = { [weak self] result in self?.receive(result) }
        }
    }

    func beginListening() {
        state = .listening
        detail = "I’m listening."
        guard let session, let recorder else { return }
        eventTask?.cancel()
        eventTask = Task {
            do {
                try await session.start()
                _ = try await session.beginTurn()
                await recorder.start()
                await readEvents(from: session)
            } catch {
                showError("Frank could not connect. Please try again.")
            }
        }
    }

    func stop() {
        eventTask?.cancel()
        eventTask = nil
        recorder?.cancel()
        audioPlayer?.stop()
        if let session { Task { await session.stopTurn() } }
        state = .ready
        detail = "Tap the button and speak naturally."
    }

    private func receive(_ result: VoiceTurnResult) {
        switch result {
        case .speechStarted:
            detail = "I can hear you."
        case .sent:
            state = .thinking
            detail = "Working on that."
        case .noSpeech:
            showError("I didn’t catch that. Tap once and try again.")
        case let .failed(message):
            showError(message)
        }
    }

    private func readEvents(from session: AssistantSession) async {
        do {
            while !Task.isCancelled {
                switch try await session.nextEvent() {
                case let .transcript(text, _):
                    transcript = text
                    state = .thinking
                    detail = "Working on that."
                case let .reply(reply, _):
                    state = .speaking
                    detail = reply.speak
                case let .audio(data):
                    do {
                        try audioPlayer?.play(data) { [weak self] in
                            self?.state = .ready
                            self?.detail = "Tap the button and speak naturally."
                        }
                    } catch {
                        showError("Frank could not play that response.")
                    }
                case .stopped:
                    state = .ready
                case let .error(message, _):
                    showError(message)
                    return
                case .connected, .ready, .frameRequired, .contextAcknowledged:
                    break
                }
            }
        } catch is CancellationError {
            return
        } catch {
            showError("Frank lost the connection. Tap once to reconnect.")
        }
    }

    private func showError(_ message: String) {
        state = .error
        detail = message
    }
}
