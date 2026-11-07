import Foundation

enum AssistantSessionError: Error, Equatable {
    case turnAlreadyActive
    case noActiveTurn
}

enum AssistantSessionEvent: Sendable {
    case connected
    case ready
    case transcript(String, confidence: Double?)
    case reply(ReplyMetadata, evidence: EvidenceMetadata?)
    case audio(Data)
    case frameRequired(maxAgeMs: Int, reason: String, requestId: String)
    case stopped
    case error(message: String, code: String?)
    case contextAcknowledged(String)
    case frameAcknowledged(frameId: String, processed: Bool?)
}

actor AssistantSession {
    private let transport: any FrankTransport
    private let sessionId: String
    private var activeRequestId: String?
    private var started = false
    private var frameSequence = 0
    private var pendingFrames: [Int: String] = [:]

    init(transport: any FrankTransport, sessionId: String = UUID().uuidString.lowercased()) {
        self.transport = transport
        self.sessionId = sessionId
    }

    func contextSessionId() -> String { sessionId }

    func sendContext(_ snapshot: ContextSnapshot) async throws {
        try await transport.send(.context(snapshot))
    }

    func repeatLastResponse() async throws {
        try await transport.send(.repeatLast())
    }

    func start() async throws {
        guard !started else { return }
        do {
            try await transport.connect()
            try await transport.send(.hello(trace: DeviceTrace(
                sessionId: sessionId,
                requestId: "hello-\(UUID().uuidString.lowercased())"
            )))
            started = true
        } catch {
            started = false
            await transport.disconnect()
            throw error
        }
    }

    func beginTurn() throws -> DeviceTrace {
        guard activeRequestId == nil else { throw AssistantSessionError.turnAlreadyActive }
        let requestId = UUID().uuidString.lowercased()
        activeRequestId = requestId
        return DeviceTrace(sessionId: sessionId, requestId: requestId)
    }

    func sendUtterance(_ text: String) async throws {
        guard let activeRequestId else { throw AssistantSessionError.noActiveTurn }
        try await transport.send(.utterance(text, trace: DeviceTrace(sessionId: sessionId, requestId: activeRequestId)))
    }

    func sendAudio(_ data: Data, mime: AudioMimeType = .wav) async throws {
        guard let activeRequestId else { throw AssistantSessionError.noActiveTurn }
        try await transport.send(.audio(data, mime: mime, trace: DeviceTrace(sessionId: sessionId, requestId: activeRequestId)))
    }

    func sendFrame(_ frame: PreparedFrame, requestId: String) async throws {
        guard let activeRequestId else { throw AssistantSessionError.noActiveTurn }
        frameSequence += 1
        pendingFrames[frameSequence] = frame.id
        try await transport.send(.frame(
            frame,
            requestId: requestId,
            sequence: frameSequence,
            trace: DeviceTrace(sessionId: sessionId, requestId: activeRequestId)
        ))
    }

    func stopTurn() async {
        if activeRequestId != nil { try? await transport.send(.stop()) }
        activeRequestId = nil
    }

    func close() async {
        activeRequestId = nil
        started = false
        await transport.disconnect()
    }

    func nextEvent() async throws -> AssistantSessionEvent {
        while true {
            let message = try await transport.receive()
            switch message {
            case let .connected(trace):
                if trace.sessionId == sessionId { return .connected }
            case let .ready(trace):
                if trace.sessionId == sessionId { return .ready }
            case let .transcript(trace, text, confidence):
                if isCurrent(trace) { return .transcript(text, confidence: confidence) }
            case let .reply(trace, metadata, evidence):
                if isCurrent(trace) { return .reply(metadata, evidence: evidence) }
            case let .audio(trace, bytes):
                if trace == nil || trace.map(isCurrent) == true {
                    activeRequestId = nil
                    return .audio(bytes)
                }
            case let .frameRequired(trace, maxAgeMs, reason, requestId):
                if isCurrent(trace) { return .frameRequired(maxAgeMs: maxAgeMs, reason: reason, requestId: requestId) }
            case let .acknowledged(sequence, trace, processed):
                guard trace == nil || trace.map(isCurrent) == true,
                      let frameId = pendingFrames.removeValue(forKey: sequence) else { continue }
                return .frameAcknowledged(frameId: frameId, processed: processed)
            case let .stopped(trace):
                if trace == nil || trace.map(isCurrent) == true {
                    activeRequestId = nil
                    return .stopped
                }
            case let .serverError(trace, message, code):
                if trace == nil || trace.map(isCurrent) == true {
                    activeRequestId = nil
                    return .error(message: message, code: code)
                }
            case let .contextAcknowledged(snapshotId, _):
                return .contextAcknowledged(snapshotId)
            case .pong, .unknown:
                continue
            }
        }
    }

    private func isCurrent(_ trace: DeviceTrace) -> Bool {
        trace.sessionId == sessionId && trace.requestId == activeRequestId
    }
}
