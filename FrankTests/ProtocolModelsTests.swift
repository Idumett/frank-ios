import Foundation
import XCTest
@testable import Frank

final class ProtocolModelsTests: XCTestCase {
    func testFrameCarriesFreshnessAndRequestIdentity() throws {
        let frame = PreparedFrame(id: "frame-1", jpeg: Data([1, 2, 3]), capturedAt: Date(timeIntervalSince1970: 1_700_000_000), quality: .good)
        let envelope = ClientEnvelope.frame(
            frame,
            requestId: "35285534-98c0-46d4-845b-7c1f5e11dc52",
            sequence: 4,
            trace: .init(sessionId: "session", requestId: "request")
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(envelope)) as? [String: Any])
        XCTAssertEqual(object["frameId"] as? String, "frame-1")
        XCTAssertEqual(object["seq"] as? Int, 4)
        XCTAssertEqual(object["quality"] as? String, "good")
        XCTAssertNotNil(object["capturedAt"])
    }
    private let decoder = JSONDecoder()

    func testDecodesTypedReplyEnvelope() throws {
        let json = #"{"type":"meta","trace":{"sessionId":"session-1","requestId":"request-1"},"reply":{"speak":"The door is ahead.","suggestedAction":"none","confidence":"high"}}"#.data(using: .utf8)!
        let message = try decoder.decode(ServerEnvelope.self, from: json)
        XCTAssertEqual(message.knownType, .meta)
        XCTAssertEqual(message.trace?.requestId, "request-1")
        XCTAssertEqual(message.reply?.speak, "The door is ahead.")
    }

    func testPreservesUnknownFutureMessageWithoutFailing() throws {
        let json = #"{"type":"new_server_feature","value":true}"#.data(using: .utf8)!
        let message = try decoder.decode(ServerEnvelope.self, from: json)
        XCTAssertNil(message.knownType)
        XCTAssertEqual(message.type, "new_server_feature")
    }

    func testAudioEnvelopeUsesProtocolMimeAndBase64() throws {
        let trace = DeviceTrace(sessionId: "session-1", requestId: "request-1")
        let data = try JSONEncoder().encode(ClientEnvelope.audio(Data([1, 2, 3]), mime: .wav, trace: trace))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "audio")
        XCTAssertEqual(object["mime"] as? String, "audio/wav")
        XCTAssertEqual(object["audioBase64"] as? String, "AQID")
    }
}
