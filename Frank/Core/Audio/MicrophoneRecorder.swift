import AVFoundation
import Foundation

struct CapturedAudioChunk: Equatable, Sendable {
    let samples: [Float]
    let sampleRate: Double

    var duration: TimeInterval { sampleRate > 0 ? Double(samples.count) / sampleRate : 0 }

    var pcm16Data: Data {
        var values = samples.map { sample -> Int16 in
            let clamped = max(-1, min(1, sample))
            return Int16(clamped * Float(Int16.max))
        }
        return values.withUnsafeMutableBytes { Data($0) }
    }
}

enum MicrophoneError: Error, Equatable {
    case permissionDenied
    case inputUnavailable
    case alreadyRecording
}

@MainActor
protocol MicrophoneCapturing: AnyObject {
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func start(onChunk: @escaping @Sendable (CapturedAudioChunk) -> Void) throws
    func stop()
}

@MainActor
final class MicrophoneRecorder: MicrophoneCapturing {
    private let engine: AVAudioEngine
    private let session: AVAudioSession
    private var chunkHandler: (@Sendable (CapturedAudioChunk) -> Void)?
    private(set) var isRecording = false

    init(engine: AVAudioEngine = AVAudioEngine(), session: AVAudioSession = .sharedInstance()) {
        self.engine = engine
        self.session = session
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start(onChunk: @escaping @Sendable (CapturedAudioChunk) -> Void) throws {
        guard !isRecording else { throw MicrophoneError.alreadyRecording }
        guard session.recordPermission == .granted else { throw MicrophoneError.permissionDenied }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw MicrophoneError.inputUnavailable }

        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        chunkHandler = onChunk
        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            guard let firstChannel = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: firstChannel, count: Int(buffer.frameLength)))
            self?.chunkHandler?(CapturedAudioChunk(samples: samples, sampleRate: format.sampleRate))
        }
        engine.prepare()
        do {
            try engine.start()
            isRecording = true
        } catch {
            input.removeTap(onBus: 0)
            chunkHandler = nil
            try? session.setActive(false)
            throw error
        }
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        chunkHandler = nil
        isRecording = false
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
