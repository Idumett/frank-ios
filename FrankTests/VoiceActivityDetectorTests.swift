import XCTest
@testable import Frank

final class VoiceActivityDetectorTests: XCTestCase {
    private func chunk(level: Float, duration: Double = 0.1) -> CapturedAudioChunk {
        CapturedAudioChunk(samples: Array(repeating: level, count: Int(16_000 * duration)), sampleRate: 16_000)
    }

    func testQuietSpeechIsAcceptedAboveTheRoomNoise() {
        var detector = VoiceActivityDetector()
        for _ in 0..<4 { _ = detector.process(chunk(level: 0.0008)) }
        guard case let .listening(level) = detector.process(chunk(level: 0.007)) else {
            return XCTFail("Expected quiet speech candidate")
        }
        XCTAssertEqual(level, 0.007, accuracy: 0.000_01)
        XCTAssertEqual(detector.process(chunk(level: 0.007)), .speechStarted)
    }

    func testEndsAfterSpeechFollowedByRealSilence() {
        var detector = VoiceActivityDetector()
        _ = detector.process(chunk(level: 0.01))
        _ = detector.process(chunk(level: 0.01))
        for _ in 0..<7 { _ = detector.process(chunk(level: 0.0002)) }
        XCTAssertEqual(detector.process(chunk(level: 0.0002)), .speechEnded)
    }

    func testAmbientNoiseReturnsOneNoSpeechResultAtTheTimeLimit() {
        var detector = VoiceActivityDetector(settings: .init(
            minimumSpeech: 0.12,
            endingSilence: 0.75,
            maximumDuration: 0.5,
            minimumLevel: 0.0015,
            noiseMultiplier: 2.5
        ))
        var results: [VoiceActivityResult] = []
        for _ in 0..<8 { results.append(detector.process(chunk(level: 0.0004))) }
        XCTAssertEqual(results.filter { $0 == .noSpeech }.count, 1)
    }

    func testShortNoiseSpikeDoesNotBecomeSpeech() {
        var detector = VoiceActivityDetector(settings: .init(maximumDuration: 0.5))
        var results = [detector.process(chunk(level: 0.04, duration: 0.03))]
        for _ in 0..<6 { results.append(detector.process(chunk(level: 0.0002))) }
        XCTAssertEqual(results.filter { $0 == .noSpeech }.count, 1)
        XCTAssertFalse(results.contains(.speechStarted))
    }

    func testTurnBufferStopsGrowingAtItsLimit() {
        var buffer = TurnAudioBuffer(maximumDuration: 0.2)
        buffer.append(chunk(level: 0.01))
        buffer.append(chunk(level: 0.01))
        buffer.append(chunk(level: 0.01))
        XCTAssertEqual(buffer.chunks.count, 2)
    }
}
