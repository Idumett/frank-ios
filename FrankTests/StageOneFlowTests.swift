import Foundation
import XCTest
@testable import Frank

private actor FlowTransport: FrankTransport {
    private var incoming: [DecodedServerMessage] = []
    private var outgoing: [ClientEnvelope] = []
    func connect() async throws {}
    func disconnect() async {}
    func send(_ message: ClientEnvelope) async throws { outgoing.append(message) }
    func receive() async throws -> DecodedServerMessage {
        guard !incoming.isEmpty else { throw URLError(.cannotParseResponse) }
        return incoming.removeFirst()
    }
    func queue(_ message: DecodedServerMessage) { incoming.append(message) }
    func sent() -> [ClientEnvelope] { outgoing }
}

final class StageOneFlowTests: XCTestCase {
    func testVoiceTurnRunsFromAudioToSpokenReply() async throws {
        let transport = FlowTransport()
        let session = AssistantSession(transport: transport, sessionId: "ios-stage-one")
        try await session.start()
        let trace = try await session.beginTurn()
        try await session.sendAudio(Data(repeating: 1, count: 100))
        await transport.queue(.transcript(trace: trace, text: "Where am I?", confidence: 0.91))
        await transport.queue(.reply(
            trace: trace,
            metadata: .init(speak: "You are near home.", suggestedAction: nil, confidence: "high"),
            evidence: nil
        ))
        await transport.queue(.audio(trace: trace, bytes: Data([9, 8, 7])))

        guard case let .transcript(text, _) = try await session.nextEvent() else { return XCTFail() }
        XCTAssertEqual(text, "Where am I?")
        guard case let .reply(reply, _) = try await session.nextEvent() else { return XCTFail() }
        XCTAssertEqual(reply.speak, "You are near home.")
        guard case let .audio(audio) = try await session.nextEvent() else { return XCTFail() }
        XCTAssertEqual(audio, Data([9, 8, 7]))
        let sentTypes = await transport.sent().map(\.type)
        XCTAssertEqual(sentTypes, ["hello", "audio"])
    }

    func testVisualTurnUsesTheRequestedFreshFrame() async throws {
        let transport = FlowTransport()
        let session = AssistantSession(transport: transport, sessionId: "ios-stage-one")
        try await session.start()
        let trace = try await session.beginTurn()
        let requestId = "afae95ca-e041-4c21-aa62-38484b35f4f2"
        await transport.queue(.frameRequired(trace: trace, maxAgeMs: 2_000, reason: "describe_scene", requestId: requestId))
        guard case let .frameRequired(maxAge, _, receivedId) = try await session.nextEvent() else { return XCTFail() }
        let frame = PreparedFrame(id: "fresh-frame", jpeg: Data([1, 2]), capturedAt: Date(), quality: .good)
        try await session.sendFrame(frame, requestId: receivedId)
        await transport.queue(.acknowledged(sequence: 1, trace: trace, processed: true))
        guard case let .frameAcknowledged(frameId, processed) = try await session.nextEvent() else { return XCTFail() }

        XCTAssertEqual(maxAge, 2_000)
        XCTAssertEqual(frameId, "fresh-frame")
        XCTAssertEqual(processed, true)
        let sent = await transport.sent()
        XCTAssertEqual(sent.last?.frameRequestId, requestId)
        XCTAssertEqual(sent.last?.frameId, "fresh-frame")
    }

    func testStopPreventsAnOldReplyEnteringTheNextTurn() async throws {
        let transport = FlowTransport()
        let session = AssistantSession(transport: transport, sessionId: "ios-stage-one")
        let old = try await session.beginTurn()
        await session.stopTurn()
        let current = try await session.beginTurn()
        await transport.queue(.reply(
            trace: old,
            metadata: .init(speak: "Old", suggestedAction: nil, confidence: nil),
            evidence: nil
        ))
        await transport.queue(.transcript(trace: current, text: "New", confidence: nil))
        guard case let .transcript(text, _) = try await session.nextEvent() else { return XCTFail() }
        XCTAssertEqual(text, "New")
    }
}
