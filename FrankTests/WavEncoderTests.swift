import XCTest
@testable import Frank

final class WavEncoderTests: XCTestCase {
    func testWritesACompleteMonoPcmWave() throws {
        let chunk = CapturedAudioChunk(samples: [0, 0.5, -0.5], sampleRate: 16_000)
        let data = try XCTUnwrap(WavEncoder.encode([chunk]))

        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data[8..<12], encoding: .ascii), "WAVE")
        XCTAssertEqual(data.count, 50)
    }

    func testRejectsAnEmptyRecording() {
        XCTAssertNil(WavEncoder.encode([]))
    }
}
