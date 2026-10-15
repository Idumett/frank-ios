import Foundation

enum DeviceProtocolError: Error, Equatable, LocalizedError {
    case invalidMessage(type: String, missing: String)
    case invalidAudio

    var errorDescription: String? {
        switch self {
        case let .invalidMessage(type, field): "Invalid \(type) message: missing \(field)."
        case .invalidAudio: "The server returned invalid audio."
        }
    }
}

enum DecodedServerMessage: Sendable {
    case connected(DeviceTrace)
    case ready(DeviceTrace)
    case contextAcknowledged(snapshotId: String, acceptedAt: String)
    case frameRequired(trace: DeviceTrace, maxAgeMs: Int, reason: String, requestId: String)
    case acknowledged(sequence: Int, trace: DeviceTrace?, processed: Bool?)
    case transcript(trace: DeviceTrace, text: String, confidence: Double?)
    case reply(trace: DeviceTrace, metadata: ReplyMetadata, evidence: EvidenceMetadata?)
    case audio(trace: DeviceTrace?, bytes: Data)
    case stopped(DeviceTrace?)
    case serverError(trace: DeviceTrace?, message: String, code: String?)
    case pong(Int64)
    case unknown(type: String)
}

struct DeviceMessageDecoder: Sendable {
    private let decoder = JSONDecoder()

    func decode(_ data: Data) throws -> DecodedServerMessage {
        let envelope = try decoder.decode(ServerEnvelope.self, from: data)
        func required<T>(_ value: T?, _ field: String) throws -> T {
            guard let value else { throw DeviceProtocolError.invalidMessage(type: envelope.type, missing: field) }
            return value
        }

        switch envelope.knownType {
        case .connected: return .connected(try required(envelope.trace, "trace"))
        case .ready: return .ready(try required(envelope.trace, "trace"))
        case .contextAck:
            return .contextAcknowledged(
                snapshotId: try required(envelope.snapshotId, "snapshotId"),
                acceptedAt: try required(envelope.acceptedAt, "acceptedAt")
            )
        case .frameRequired:
            return .frameRequired(
                trace: try required(envelope.trace, "trace"),
                maxAgeMs: try required(envelope.maxAgeMs, "maxAgeMs"),
                reason: try required(envelope.reason, "reason"),
                requestId: try required(envelope.frameRequestId, "frameRequestId")
            )
        case .ack:
            return .acknowledged(sequence: try required(envelope.seq, "seq"), trace: envelope.trace, processed: envelope.processed)
        case .transcript:
            return .transcript(
                trace: try required(envelope.trace, "trace"),
                text: try required(envelope.transcript, "transcript"),
                confidence: envelope.confidence
            )
        case .meta:
            return .reply(
                trace: try required(envelope.trace, "trace"),
                metadata: try required(envelope.reply, "reply"),
                evidence: envelope.evidence
            )
        case .audio:
            guard let encoded = envelope.bytesBase64, let bytes = Data(base64Encoded: encoded) else {
                throw DeviceProtocolError.invalidAudio
            }
            return .audio(trace: envelope.trace, bytes: bytes)
        case .stopped: return .stopped(envelope.trace)
        case .error:
            return .serverError(trace: envelope.trace, message: try required(envelope.message, "message"), code: envelope.code)
        case .pong: return .pong(try required(envelope.t, "t"))
        case nil: return .unknown(type: envelope.type)
        }
    }
}
