import Foundation

protocol FrankTransport: Sendable {
    func connect() async throws
    func disconnect() async
    func send(_ message: ClientEnvelope) async throws
    func receive() async throws -> DecodedServerMessage
}

protocol WebSocketConnection: Sendable {
    func resume()
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel()
}

final class SystemWebSocketConnection: WebSocketConnection, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(request: URLRequest, session: URLSession = .shared) {
        task = session.webSocketTask(with: request)
    }

    func resume() { task.resume() }
    func send(_ message: URLSessionWebSocketTask.Message) async throws { try await task.send(message) }
    func receive() async throws -> URLSessionWebSocketTask.Message { try await task.receive() }
    func cancel() { task.cancel(with: .normalClosure, reason: nil) }
}

actor FrankWebSocketTransport: FrankTransport {
    typealias ConnectionFactory = @Sendable (URLRequest) -> any WebSocketConnection

    private let configuration: AppConfiguration
    private let makeConnection: ConnectionFactory
    private let decoder: DeviceMessageDecoder
    private var connection: (any WebSocketConnection)?

    init(
        configuration: AppConfiguration = .current,
        decoder: DeviceMessageDecoder = .init(),
        makeConnection: @escaping ConnectionFactory = { SystemWebSocketConnection(request: $0) }
    ) {
        self.configuration = configuration
        self.decoder = decoder
        self.makeConnection = makeConnection
    }

    func connect() async throws {
        guard connection == nil else { return }
        guard configuration.isConfigured, let serverURL = configuration.serverURL else {
            throw TransportError.missingConfiguration
        }
        guard let streamURL = Self.deviceStreamURL(from: serverURL) else {
            throw TransportError.invalidServerURL
        }
        var request = URLRequest(url: streamURL)
        request.timeoutInterval = 15
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("frank-ios/1", forHTTPHeaderField: "User-Agent")
        let newConnection = makeConnection(request)
        connection = newConnection
        newConnection.resume()
    }

    func disconnect() async {
        connection?.cancel()
        connection = nil
    }

    func send(_ message: ClientEnvelope) async throws {
        guard let connection else { throw TransportError.notConnected }
        let data = try JSONEncoder().encode(message)
        try await connection.send(.data(data))
    }

    func receive() async throws -> DecodedServerMessage {
        guard let connection else { throw TransportError.notConnected }
        let message = try await connection.receive()
        switch message {
        case let .data(data): return try decoder.decode(data)
        case let .string(text): return try decoder.decode(Data(text.utf8))
        @unknown default: throw TransportError.unsupportedFrame
        }
    }

    private static func deviceStreamURL(from baseURL: URL) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        switch components.scheme?.lowercased() {
        case "https": components.scheme = "wss"
        case "http": components.scheme = "ws"
        case "wss", "ws": break
        default: return nil
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, "v1/device/stream"].filter { !$0.isEmpty }.joined(separator: "/"))
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

enum TransportError: Error, Equatable {
    case missingConfiguration
    case invalidServerURL
    case notConnected
    case unsupportedFrame
}
