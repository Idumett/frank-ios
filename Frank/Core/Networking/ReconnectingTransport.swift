import Foundation

struct ReconnectPolicy: Equatable, Sendable {
    let delays: [Duration]

    static let standard = ReconnectPolicy(delays: [
        .milliseconds(350), .milliseconds(700), .seconds(1), .seconds(2), .seconds(4), .seconds(8)
    ])
}

actor ReconnectingTransport: FrankTransport {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private let transport: any FrankTransport
    private let policy: ReconnectPolicy
    private let sleep: Sleep
    private var closed = false
    private var reconnecting: Task<Void, Error>?

    init(
        transport: any FrankTransport,
        policy: ReconnectPolicy = .standard,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.transport = transport
        self.policy = policy
        self.sleep = sleep
    }

    func connect() async throws {
        closed = false
        try await transport.connect()
    }

    func disconnect() async {
        closed = true
        reconnecting?.cancel()
        reconnecting = nil
        await transport.disconnect()
    }

    func send(_ message: ClientEnvelope) async throws {
        guard !closed else { throw TransportError.notConnected }
        do {
            try await transport.send(message)
        } catch {
            try await reconnect()
            try await transport.send(message)
        }
    }

    func receive() async throws -> DecodedServerMessage {
        guard !closed else { throw TransportError.notConnected }
        do {
            return try await transport.receive()
        } catch {
            try Task.checkCancellation()
            try await reconnect()
            return try await transport.receive()
        }
    }

    func recoverIfNeeded() async throws {
        guard !closed else { return }
        try await reconnect()
    }

    private func reconnect() async throws {
        if let reconnecting {
            return try await reconnecting.value
        }
        let task = Task {
            var lastError: Error = TransportError.notConnected
            for delay in policy.delays {
                try Task.checkCancellation()
                await transport.disconnect()
                do {
                    try await sleep(delay)
                    try await transport.connect()
                    return
                } catch {
                    lastError = error
                }
            }
            throw lastError
        }
        reconnecting = task
        defer { reconnecting = nil }
        try await task.value
    }
}
