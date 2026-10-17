import Foundation
import XCTest
@testable import Frank

private actor SessionTransport: FrankTransport {
    var messages: [DecodedServerMessage] = []
    private(set) var sent: [ClientEnvelope] = []
    func connect() async throws {}
    func disconnect() async {}
    func send(_ message: ClientEnvelope) async throws { sent.append(message) }
    func receive() async throws -> DecodedServerMessage {
        guard !messages.isEmpty else { throw URLError(.cannotParseResponse) }
        return messages.removeFirst()
    }
    func add(_ message: DecodedServerMessage) { messages.append(message) }
    func sentMessages() -> [ClientEnvelope] { sent }
}

final class AssistantSessionTests: XCTestCase {
    func testOwnsOneTurnAndRejectsAnOverlappingRequest() async throws {
        let transport = SessionTransport()
        let session = AssistantSession(transport: transport, sessionId: "session-1")
        try await session.start()
        let trace = try await session.beginTurn()
        XCTAssertEqual(trace.sessionId, "session-1")
        do {
            _ = try await session.beginTurn()
            XCTFail("Expected active turn error")
        } catch {
            XCTAssertEqual(error as? AssistantSessionError, .turnAlreadyActive)
        }
        try await session.sendUtterance("Hello Frank")
        let sent = await transport.sentMessages()
        XCTAssertEqual(sent.map(\.type), ["hello", "utterance"])
    }

    func testSkipsAReplyFromAnOlderTurn() async throws {
        let transport = SessionTransport()
        let session = AssistantSession(transport: transport, sessionId: "session-1")
        try await session.start()
        let current = try await session.beginTurn()
        await transport.add(.reply(
            trace: DeviceTrace(sessionId: "session-1", requestId: "old-request"),
            metadata: .init(speak: "Old answer", suggestedAction: nil, confidence: nil), evidence: nil
        ))
        await transport.add(.transcript(trace: current, text: "Current words", confidence: 0.8))

        guard case let .transcript(text, _) = try await session.nextEvent() else {
            return XCTFail("Expected current transcript")
        }
        XCTAssertEqual(text, "Current words")
    }

    func testStopClearsTheTurnBeforeStartingAnother() async throws {
        let transport = SessionTransport()
        let session = AssistantSession(transport: transport)
        _ = try await session.beginTurn()
        await session.stopTurn()
        XCTAssertNoThrow(try session.beginTurn())
    }
}
