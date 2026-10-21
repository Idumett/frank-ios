import AVFoundation
import Foundation

enum AudioSessionChange: Equatable, Sendable {
    case interrupted
    case interruptionEnded(shouldResume: Bool)
    case routeChanged
}

@MainActor
final class AudioSessionController {
    private let session: AVAudioSession
    private var observers: [NSObjectProtocol] = []
    var onChange: ((AudioSessionChange) -> Void)?

    init(session: AVAudioSession = .sharedInstance(), center: NotificationCenter = .default) {
        self.session = session
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            let change = Self.interruption(from: note.userInfo ?? [:])
            Task { @MainActor in self?.onChange?(change) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onChange?(.routeChanged) }
        })
    }

    func prepareForPlayback() throws {
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated static func interruption(from info: [AnyHashable: Any]) -> AudioSessionChange {
        let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
        guard AVAudioSession.InterruptionType(rawValue: rawType) == .ended else { return .interrupted }
        let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        return .interruptionEnded(shouldResume: AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume))
    }

}
