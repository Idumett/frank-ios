import Combine
import Foundation

@MainActor
final class AssistantViewModel: ObservableObject {
    @Published private(set) var state: AssistantState = .ready
    @Published private(set) var detail = "Tap the button and speak naturally."
    @Published private(set) var transcript = ""
    @Published private(set) var lastReply = ""
    @Published private(set) var suggestedAction: String?

    private let session: AssistantSession?
    private let audioPlayer: (any ResponseAudioPlaying)?
    private let audioSession: AudioSessionController?
    private let camera: (any PreparedFrameProviding)?
    private let contextEngine: ContextEngine?
    private var recorder: VoiceTurnRecorder?
    private var eventTask: Task<Void, Never>?
    private var turnGeneration = 0

    init(
        session: AssistantSession? = nil,
        microphone: (any MicrophoneCapturing)? = nil,
        audioPlayer: (any ResponseAudioPlaying)? = nil,
        audioSession: AudioSessionController? = nil,
        camera: (any PreparedFrameProviding)? = nil,
        contextEngine: ContextEngine? = nil
    ) {
        self.session = session
        self.audioPlayer = audioPlayer
        self.audioSession = audioSession
        self.camera = camera
        self.contextEngine = contextEngine
        audioSession?.onChange = { [weak self] change in
            if case .interrupted = change { self?.stopForInterruption() }
        }
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
        turnGeneration += 1
        let generation = turnGeneration
        state = .listening
        detail = "I’m listening."
        guard let session, let recorder else { return }
        eventTask?.cancel()
        eventTask = Task {
            do {
                try await session.start()
                _ = try await session.beginTurn()
                async let cameraReady = camera?.start()
                if let contextEngine {
                    let snapshot = contextEngine.snapshot(sessionId: await session.contextSessionId(), appState: .listening)
                    try await session.sendContext(snapshot)
                }
                await recorder.start()
                _ = await cameraReady
                await readEvents(from: session, generation: generation)
            } catch {
                guard generation == turnGeneration else { return }
                showError("Frank could not connect. Please try again.")
            }
        }
    }

    func stop() {
        turnGeneration += 1
        eventTask?.cancel()
        eventTask = nil
        recorder?.cancel()
        audioPlayer?.stop()
        audioSession?.deactivate()
        if let session { Task { await session.stopTurn() } }
        state = .ready
        detail = "Tap the button and speak naturally."
    }

    func repeatLastResponse() {
        guard let session else { return }
        Task {
            do {
                try audioSession?.prepareForPlayback()
                try await session.repeatLastResponse()
                state = .speaking
                detail = "Repeating the last response."
            } catch {
                showError("Frank could not repeat that response.")
            }
        }
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

    private func readEvents(from session: AssistantSession, generation: Int) async {
        do {
            while !Task.isCancelled, generation == turnGeneration {
                switch try await session.nextEvent() {
                case let .transcript(text, _):
                    guard generation == turnGeneration else { return }
                    transcript = text
                    state = .thinking
                    detail = "Working on that."
                case let .reply(reply, _):
                    guard generation == turnGeneration else { return }
                    state = .speaking
                    detail = reply.speak
                    lastReply = reply.speak
                    suggestedAction = reply.suggestedAction
                case let .audio(data):
                    guard generation == turnGeneration else { return }
                    do {
                        try audioSession?.prepareForPlayback()
                        try audioPlayer?.play(data) { [weak self] in
                            guard self?.turnGeneration == generation else { return }
                            self?.audioSession?.deactivate()
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
                case let .frameRequired(maxAgeMs, _, requestId):
                    guard let frame = await camera?.freshest(maxAgeMs: maxAgeMs) else {
                        showError("I need a clearer current view. Point the camera and try again.")
                        await session.stopTurn()
                        return
                    }
                    try await session.sendFrame(frame, requestId: requestId)
                    detail = "Checking the current view."
                case .connected, .ready, .contextAcknowledged, .frameAcknowledged:
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

    private func stopForInterruption() {
        stop()
        detail = "Frank paused because another audio session started."
    }
}
