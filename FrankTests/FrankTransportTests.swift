import Foundation
import XCTest
@testable import Frank

private final class MockSocket: WebSocketConnection, @unchecked Sendable {
    var resumed = false
    var cancelled = false
    var sent: [URLSessionWebSocketTask.Message] = []
    var incoming: [URLSessionWebSocketTask.Message] = []

    func resume() { resumed = true }
    func send(_ message: URLSessionWebSocketTask.Message) async throws { sent.append(message) }
    func receive() async throws -> URLSessionWebSocketTask.Message {
        guard !incoming.isEmpty else { throw URLError(.networkConnectionLost) }
        return incoming.removeFirst()
    }
    func cancel() { cancelled = true }
}

final class FrankTransportTests: XCTestCase {
    func testConnectBuildsAuthenticatedWebSocketAndDecodesMessages() async throws {
        let socket = MockSocket()
        socket.incoming = [.data(DeviceProtocolFixtures.connected)]
        final class RequestBox: @unchecked Sendable { var value: URLRequest? }
        let captured = RequestBox()
        let transport = FrankWebSocketTransport(
            configuration: .init(serverURL: URL(string: "https://example.com")!, accessToken: "secret-token"),
            makeConnection: { request in captured.value = request; return socket }
        )

        try await transport.connect()
        XCTAssertEqual(captured.value?.url?.absoluteString, "wss://example.com/v1/device/stream")
        XCTAssertEqual(captured.value?.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        XCTAssertTrue(socket.resumed)
        guard case .connected = try await transport.receive() else { return XCTFail("Expected connected") }

        try await transport.send(.ping(42))
        XCTAssertEqual(socket.sent.count, 1)
        await transport.disconnect()
        XCTAssertTrue(socket.cancelled)
    }

    func testRejectsMissingConfigurationBeforeOpeningSocket() async {
        let transport = FrankWebSocketTransport(configuration: .init(serverURL: nil, accessToken: ""))
        do {
            try await transport.connect()
            XCTFail("Expected configuration error")
        } catch {
            XCTAssertEqual(error as? TransportError, .missingConfiguration)
        }
    }
}
