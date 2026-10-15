import Foundation

enum DeviceProtocolFixtures {
    static func data(_ json: String) -> Data { Data(json.utf8) }

    static let connected = data(#"{"type":"connected","trace":{"sessionId":"session-fixture","requestId":"request-fixture"}}"#)
    static let transcript = data(#"{"type":"transcript","trace":{"sessionId":"session-fixture","requestId":"request-fixture"},"transcript":"Where are my keys?","confidence":0.91}"#)
    static let reply = data(#"{"type":"meta","trace":{"sessionId":"session-fixture","requestId":"request-fixture"},"reply":{"speak":"Your keys are beside the door.","suggestedAction":"none","confidence":"high"}}"#)
    static let audio = data(#"{"type":"audio","trace":{"sessionId":"session-fixture","requestId":"request-fixture"},"mime":"audio/mpeg","bytesBase64":"AQID"}"#)
}
