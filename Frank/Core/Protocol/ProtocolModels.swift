import Foundation

let frankProtocolVersion = 1

struct DeviceTrace: Codable, Equatable, Sendable {
    let sessionId: String
    let requestId: String
}

enum FrankIntent: String, Codable, Sendable {
    case readText = "read_text"
    case describeScene = "describe_scene"
    case rememberThis = "remember_this"
    case recall
    case help
}

enum AudioMimeType: String, Codable, Sendable {
    case wav = "audio/wav"
    case webm = "audio/webm"
    case mpeg = "audio/mpeg"
}

enum ImageMimeType: String, Codable, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case webp = "image/webp"
}

struct ClientEnvelope: Encodable, Sendable {
    let type: String
    var trace: DeviceTrace?
    var text: String?
    var sentAt: String?
    var mime: String?
    var audioBase64: String?
    var frameRequestId: String?
    var frameId: String?
    var seq: Int?
    var bytesBase64: String?
    var capturedAt: String?
    var ageMs: Int?
    var quality: String?
    var snapshot: ContextSnapshot?
    var intent: FrankIntent?
    var query: String?
    var t: Int64?

    static func hello(trace: DeviceTrace) -> Self { .init(type: "hello", trace: trace) }
    static func utterance(_ text: String, trace: DeviceTrace) -> Self {
        .init(type: "utterance", trace: trace, text: text, sentAt: ISO8601DateFormatter().string(from: Date()))
    }
    static func audio(_ data: Data, mime: AudioMimeType, trace: DeviceTrace) -> Self {
        .init(type: "audio", trace: trace, sentAt: ISO8601DateFormatter().string(from: Date()), mime: mime.rawValue, audioBase64: data.base64EncodedString())
    }
    static func frame(_ frame: PreparedFrame, requestId: String, sequence: Int, trace: DeviceTrace) -> Self {
        .init(
            type: "frame",
            trace: trace,
            mime: ImageMimeType.jpeg.rawValue,
            frameRequestId: requestId,
            frameId: frame.id,
            seq: sequence,
            bytesBase64: frame.jpeg.base64EncodedString(),
            capturedAt: ISO8601DateFormatter().string(from: frame.capturedAt),
            ageMs: frame.ageMs(),
            quality: frame.quality.rawValue
        )
    }
    static func context(_ snapshot: ContextSnapshot) -> Self { .init(type: "context_snapshot", snapshot: snapshot) }
    static func stop() -> Self { .init(type: "stop") }
    static func repeatLast() -> Self { .init(type: "repeat") }
    static func ping(_ value: Int64) -> Self { .init(type: "ping", t: value) }
}

struct ReplyMetadata: Codable, Equatable, Sendable {
    let speak: String
    let suggestedAction: String?
    let confidence: String?
}

struct EvidenceMetadata: Codable, Equatable, Sendable {
    let frameId: String
    let capturedAt: String
    let ageMs: Int
    let quality: String
}

struct ServerEnvelope: Decodable, Sendable {
    let type: String
    let trace: DeviceTrace?
    let transcript: String?
    let confidence: Double?
    let reply: ReplyMetadata?
    let mime: String?
    let bytesBase64: String?
    let message: String?
    let code: String?
    let seq: Int?
    let processed: Bool?
    let maxAgeMs: Int?
    let reason: String?
    let frameRequestId: String?
    let evidence: EvidenceMetadata?
    let snapshotId: String?
    let acceptedAt: String?
    let t: Int64?

    var knownType: ServerMessageType? { ServerMessageType(rawValue: type) }
}

enum ServerMessageType: String, Codable, Sendable {
    case connected, ready, contextAck = "context_ack", frameRequired = "frame_required"
    case ack, transcript, meta, audio, stopped, error, pong
}
