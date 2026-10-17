import Foundation

enum VoiceActivityResult: Equatable, Sendable {
    case listening(level: Float)
    case speechStarted
    case speechEnded
    case noSpeech
    case maximumDurationReached
}

struct VoiceActivityDetector: Sendable {
    struct Settings: Equatable, Sendable {
        var minimumSpeech = 0.12
        var endingSilence = 0.75
        var maximumDuration = 20.0
        var minimumLevel: Float = 0.0015
        var noiseMultiplier: Float = 2.5
    }

    private let settings: Settings
    private var noiseFloor: Float = 0.0008
    private var totalDuration = 0.0
    private var possibleSpeech = 0.0
    private var silenceAfterSpeech = 0.0
    private var heardSpeech = false
    private var finished = false

    init(settings: Settings = .init()) {
        self.settings = settings
    }

    mutating func process(_ chunk: CapturedAudioChunk) -> VoiceActivityResult {
        guard !finished else { return .listening(level: 0) }
        let duration = chunk.duration
        totalDuration += duration
        let level = Self.rms(chunk.samples)
        let peak = chunk.samples.lazy.map { abs($0) }.max() ?? 0
        let threshold = max(settings.minimumLevel, noiseFloor * settings.noiseMultiplier)
        let active = level >= threshold || peak >= threshold * 2

        if !heardSpeech, level < threshold {
            noiseFloor = noiseFloor * 0.9 + level * 0.1
        }

        if active {
            silenceAfterSpeech = 0
            possibleSpeech += duration
            if !heardSpeech, possibleSpeech >= settings.minimumSpeech {
                heardSpeech = true
                return .speechStarted
            }
        } else if heardSpeech {
            silenceAfterSpeech += duration
            if silenceAfterSpeech >= settings.endingSilence {
                finished = true
                return .speechEnded
            }
        } else {
            possibleSpeech = 0
        }

        if totalDuration >= settings.maximumDuration {
            finished = true
            return heardSpeech ? .maximumDurationReached : .noSpeech
        }
        return .listening(level: level)
    }

    private static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let power = samples.reduce(Float.zero) { $0 + $1 * $1 } / Float(samples.count)
        return sqrt(power)
    }
}

struct TurnAudioBuffer: Sendable {
    private(set) var chunks: [CapturedAudioChunk] = []
    private(set) var duration = 0.0
    let maximumDuration: TimeInterval

    init(maximumDuration: TimeInterval = 20) {
        self.maximumDuration = maximumDuration
    }

    mutating func append(_ chunk: CapturedAudioChunk) {
        guard duration + chunk.duration <= maximumDuration else { return }
        chunks.append(chunk)
        duration += chunk.duration
    }

    mutating func reset() {
        chunks.removeAll(keepingCapacity: true)
        duration = 0
    }
}
