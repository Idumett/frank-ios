import Foundation
import XCTest
@testable import Frank

private actor ScriptedTransport: FrankTransport {
    var connectFailures: [Bool]
    var receiveFailures: [Bool]
    private(set) var connectCalls = 0
    private(set) var disconnectCalls = 0

    init(connectFailures: [Bool], receiveFailures: [Bool]) {
        self.connectFailures = connectFailures
        self.receiveFailures = receiveFailures
    }

    func connect() async throws {
        connectCalls += 1
        if !connectFailures.isEmpty, connectFailures.removeFirst() { throw URLError(.cannotConnectToHost) }
    }
    func disconnect() async { disconnectCalls += 1 }
    func send(_ message: ClientEnvelope) async throws {}
    func receive() async throws -> DecodedServerMessage {
        if !receiveFailures.isEmpty, receiveFailures.removeFirst() { throw URLError(.networkConnectionLost) }
        return .pong(1)
    }
    func counts() -> (Int, Int) { (connectCalls, disconnectCalls) }
}

final class ReconnectingTransportTests: XCTestCase {
    func testReconnectsWithBoundedBackoffAfterNetworkLoss() async throws {
        let base = ScriptedTransport(connectFailures: [false, true, false], receiveFailures: [true, false])
        actor Delays { var values: [Duration] = []; func add(_ value: Duration) { values.append(value) } }
        let delays = Delays()
        let transport = ReconnectingTransport(
            transport: base,
            policy: .init(delays: [.milliseconds(10), .milliseconds(20)]),
            sleep: { await delays.add($0) }
        )

        try await transport.connect()
        guard case .pong = try await transport.receive() else { return XCTFail("Expected pong") }
        let counts = await base.counts()
        XCTAssertEqual(counts.0, 3)
        XCTAssertEqual(counts.1, 2)
        let usedDelays = await delays.values
        XCTAssertEqual(usedDelays, [.milliseconds(10), .milliseconds(20)])
    }

    func testExplicitDisconnectStopsRecovery() async {
        let base = ScriptedTransport(connectFailures: [], receiveFailures: [])
        let transport = ReconnectingTransport(transport: base)
        try? await transport.connect()
        await transport.disconnect()
        do {
            _ = try await transport.receive()
            XCTFail("Expected disconnected error")
        } catch {
            XCTAssertEqual(error as? TransportError, .notConnected)
        }
    }
}
