import Foundation
import XCTest
@testable import Frank

final class ProtocolModelsTests: XCTestCase {
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
