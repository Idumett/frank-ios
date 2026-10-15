import XCTest
@testable import Frank

final class DeviceMessageDecoderTests: XCTestCase {
    private let decoder = DeviceMessageDecoder()

    func testDecodesRepresentativeServerSequence() throws {
        guard case let .connected(trace) = try decoder.decode(DeviceProtocolFixtures.connected) else {
            return XCTFail("Expected connected")
        }
        XCTAssertEqual(trace.sessionId, "session-fixture")

        guard case let .transcript(_, text, confidence) = try decoder.decode(DeviceProtocolFixtures.transcript) else {
            return XCTFail("Expected transcript")
        }
        XCTAssertEqual(text, "Where are my keys?")
        XCTAssertEqual(confidence, 0.91)

        guard case let .reply(_, metadata, _) = try decoder.decode(DeviceProtocolFixtures.reply) else {
            return XCTFail("Expected reply")
        }
        XCTAssertEqual(metadata.speak, "Your keys are beside the door.")

        guard case let .audio(_, bytes) = try decoder.decode(DeviceProtocolFixtures.audio) else {
            return XCTFail("Expected audio")
        }
        XCTAssertEqual(bytes, Data([1, 2, 3]))
    }

    func testRejectsMalformedKnownMessage() {
        let missingReply = DeviceProtocolFixtures.data(#"{"type":"meta","trace":{"sessionId":"s","requestId":"r"}}"#)
        XCTAssertThrowsError(try decoder.decode(missingReply)) { error in
            XCTAssertEqual(error as? DeviceProtocolError, .invalidMessage(type: "meta", missing: "reply"))
        }
    }

    func testKeepsUnknownFutureMessageNonFatal() throws {
        let future = DeviceProtocolFixtures.data(#"{"type":"future_capability","schemaVersion":2}"#)
        guard case let .unknown(type) = try decoder.decode(future) else {
            return XCTFail("Expected unknown message")
        }
        XCTAssertEqual(type, "future_capability")
    }
}
