import Foundation

protocol FrankTransport: Sendable {
    func connect() async throws
    func disconnect() async
}

actor FrankWebSocketTransport: FrankTransport {
    private let configuration: AppConfiguration
    private var task: URLSessionWebSocketTask?

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    func connect() async throws {
        guard let serverURL = configuration.serverURL else {
            throw TransportError.missingConfiguration
        }
        var request = URLRequest(url: serverURL.appending(path: "v1/device/stream"))
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        task = socket
        socket.resume()
    }

    func disconnect() async {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
}

enum TransportError: Error {
    case missingConfiguration
}
