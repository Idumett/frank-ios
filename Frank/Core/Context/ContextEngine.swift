import AVFoundation
import CoreLocation
import CoreMotion
import Foundation
import UIKit

@MainActor
final class ContextEngine {
    private let locations: CLLocationManager

    init(locations: CLLocationManager = CLLocationManager()) {
        self.locations = locations
        UIDevice.current.isBatteryMonitoringEnabled = true
        if locations.authorizationStatus == .authorizedAlways || locations.authorizationStatus == .authorizedWhenInUse {
            locations.startUpdatingLocation()
        }
    }

    func snapshot(sessionId: String, appState: AssistantState, frame: PreparedFrame? = nil, now: Date = Date()) -> ContextSnapshot {
        let iso = ISO8601DateFormatter()
        let captured = iso.string(from: now)
        let expires = iso.string(from: now.addingTimeInterval(30))
        let system = ContextProvenance(source: .system, collectedAt: captured)
        let sensor = ContextProvenance(source: .sensor, collectedAt: captured)
        let appSource = ContextProvenance(source: .app, collectedAt: captured)
        func known<T: Encodable & Sendable>(_ value: T, source: ContextProvenance = system) -> ContextValue<T> {
            .known(value: value, observedAt: captured, expiresAt: expires, provenance: source)
        }
        func permission(_ name: String, granted: Bool?, source: ContextProvenance = system) -> ContextValue<String> {
            if granted == true { return known("granted", source: source) }
            if granted == false { return .denied(permission: name, provenance: source) }
            return known("not_requested", source: source)
        }

        let locationValue: ContextValue<LocationContext>
        let movementValue: ContextValue<MovementContext>
        if let location = locations.location, location.horizontalAccuracy >= 0, location.timestamp.addingTimeInterval(30) >= now {
            locationValue = known(.init(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracyMeters: location.horizontalAccuracy,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil
            ), source: sensor)
            let speed = max(0, location.speed)
            let state = speed < 0.4 ? "stationary" : speed < 3 ? "walking" : "vehicle"
            movementValue = known(.init(
                state: state,
                confidence: location.horizontalAccuracy <= 30 ? "high" : "low",
                speedMetersPerSecond: speed,
                headingDegrees: location.course >= 0 ? location.course : nil
            ), source: sensor)
        } else {
            locationValue = .unknown(reason: "not_collected", provenance: sensor)
            movementValue = .unknown(reason: "not_collected", provenance: sensor)
        }

        let evidence: ContextValue<EvidenceContext> = frame.map {
            known(.init(frameId: $0.id, capturedAt: iso.string(from: $0.capturedAt), ageMs: $0.ageMs(at: now), quality: $0.quality.rawValue), source: sensor)
        } ?? .unknown(reason: "not_collected", provenance: sensor)
        let battery = UIDevice.current.batteryLevel

        return ContextSnapshot(
            snapshotId: UUID().uuidString.lowercased(), sessionId: sessionId, capturedAt: captured, expiresAt: expires,
            time: known(.init(timezone: TimeZone.current.identifier, utcOffsetMinutes: TimeZone.current.secondsFromGMT(for: now) / 60)),
            permissions: .init(
                microphone: permission("microphone", granted: Self.microphonePermission),
                camera: permission("camera", granted: Self.cameraPermission),
                location: permission("location", granted: Self.locationPermission(locations.authorizationStatus)),
                activity: permission("activity", granted: Self.activityPermission)
            ),
            device: .init(
                connectivity: .unknown(reason: "not_collected", provenance: system),
                screen: known("interactive"),
                headphones: .unknown(reason: "not_collected", provenance: system),
                batteryPercent: battery >= 0 ? known(Int((battery * 100).rounded())) : .unknown(reason: "unavailable", provenance: system),
                cameraAvailable: known(AVCaptureDevice.default(for: .video) != nil)
            ),
            app: known(.init(state: appState.contextName, sessionOpen: true), source: appSource),
            location: locationValue, movement: movementValue, evidence: evidence
        )
    }

    private static var microphonePermission: Bool? {
        switch AVAudioApplication.shared.recordPermission { case .granted: true; case .denied: false; default: nil }
    }
    private static var cameraPermission: Bool? {
        switch AVCaptureDevice.authorizationStatus(for: .video) { case .authorized: true; case .denied, .restricted: false; default: nil }
    }
    private static func locationPermission(_ status: CLAuthorizationStatus) -> Bool? {
        switch status { case .authorizedAlways, .authorizedWhenInUse: true; case .denied, .restricted: false; default: nil }
    }
    private static var activityPermission: Bool? {
        switch CMMotionActivityManager.authorizationStatus() { case .authorized: true; case .denied, .restricted: false; default: nil }
    }
}

private extension AssistantState {
    var contextName: String {
        switch self { case .ready, .disconnected: "idle"; case .listening: "listening"; case .thinking: "thinking"; case .speaking: "speaking"; case .error: "error" }
    }
}
