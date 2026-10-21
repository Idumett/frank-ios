import Foundation

struct ContextProvenance: Encodable, Sendable {
    enum Source: String, Encodable, Sendable { case system = "ios_system", sensor = "ios_sensor", app = "ios_app" }
    let source: Source
    let collectedAt: String
}

enum ContextValue<Value: Encodable & Sendable>: Encodable, Sendable {
    case known(value: Value, observedAt: String, expiresAt: String, provenance: ContextProvenance)
    case unknown(reason: String, provenance: ContextProvenance)
    case denied(permission: String, provenance: ContextProvenance)
    case stale(lastObservedAt: String, expiredAt: String, provenance: ContextProvenance)
    case conflicting(reason: String, sources: [String], provenance: ContextProvenance)

    private enum CodingKeys: String, CodingKey {
        case status, value, observedAt, expiresAt, provenance, reason, permission, lastObservedAt, expiredAt, sources
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .known(value, observedAt, expiresAt, provenance):
            try box.encode("known", forKey: .status)
            try box.encode(value, forKey: .value)
            try box.encode(observedAt, forKey: .observedAt)
            try box.encode(expiresAt, forKey: .expiresAt)
            try box.encode(provenance, forKey: .provenance)
        case let .unknown(reason, provenance):
            try box.encode("unknown", forKey: .status)
            try box.encode(reason, forKey: .reason)
            try box.encode(provenance, forKey: .provenance)
        case let .denied(permission, provenance):
            try box.encode("denied", forKey: .status)
            try box.encode(permission, forKey: .permission)
            try box.encode(provenance, forKey: .provenance)
        case let .stale(lastObservedAt, expiredAt, provenance):
            try box.encode("stale", forKey: .status)
            try box.encode(lastObservedAt, forKey: .lastObservedAt)
            try box.encode(expiredAt, forKey: .expiredAt)
            try box.encode(provenance, forKey: .provenance)
        case let .conflicting(reason, sources, provenance):
            try box.encode("conflicting", forKey: .status)
            try box.encode(reason, forKey: .reason)
            try box.encode(sources, forKey: .sources)
            try box.encode(provenance, forKey: .provenance)
        }
    }
}

struct TimeContext: Encodable, Sendable { let timezone: String; let utcOffsetMinutes: Int }
struct LocationContext: Encodable, Sendable { let latitude: Double; let longitude: Double; let accuracyMeters: Double; let altitudeMeters: Double? }
struct MovementContext: Encodable, Sendable { let state: String; let confidence: Double; let speedMetersPerSecond: Double?; let headingDegrees: Double? }
struct EvidenceContext: Encodable, Sendable { let frameId: String; let capturedAt: String; let ageMs: Int; let quality: String }
struct AppContext: Encodable, Sendable { let state: String; let sessionOpen: Bool }
struct PermissionContext: Encodable, Sendable {
    let microphone: ContextValue<String>; let camera: ContextValue<String>; let location: ContextValue<String>; let activity: ContextValue<String>
}
struct DeviceContext: Encodable, Sendable {
    let connectivity: ContextValue<String>; let screen: ContextValue<String>; let headphones: ContextValue<Bool>; let batteryPercent: ContextValue<Int>; let cameraAvailable: ContextValue<Bool>
}

struct ContextSnapshot: Encodable, Sendable {
    let schemaVersion = "1"
    let snapshotId: String
    let sessionId: String
    let capturedAt: String
    let expiresAt: String
    let time: ContextValue<TimeContext>
    let permissions: PermissionContext
    let device: DeviceContext
    let app: ContextValue<AppContext>
    let location: ContextValue<LocationContext>
    let movement: ContextValue<MovementContext>
    let evidence: ContextValue<EvidenceContext>
}
