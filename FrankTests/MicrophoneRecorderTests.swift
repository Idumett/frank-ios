import XCTest
@testable import Frank

final class MicrophoneRecorderTests: XCTestCase {
    func testCapturedAudioReportsDurationAndConvertsToBoundedPcm() {
        let chunk = CapturedAudioChunk(samples: [-2, -1, 0, 0.5, 1, 2], sampleRate: 3)
        XCTAssertEqual(chunk.duration, 2)
        XCTAssertEqual(chunk.pcm16Data.count, 12)
        let values = chunk.pcm16Data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        XCTAssertEqual(values[0], -Int16.max)
        XCTAssertEqual(values[2], 0)
        XCTAssertEqual(values[4], Int16.max)
        XCTAssertEqual(values[5], Int16.max)
    }

    func testEmptyChunkHasNoDurationOrPayload() {
        let chunk = CapturedAudioChunk(samples: [], sampleRate: 48_000)
        XCTAssertEqual(chunk.duration, 0)
        XCTAssertTrue(chunk.pcm16Data.isEmpty)
    }
}
