import Foundation

enum AssistantState: String, Equatable, Sendable {
    case ready
    case listening
    case thinking
    case speaking
    case disconnected
    case error

    var announcement: String {
        switch self {
        case .ready: "Frank is ready"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .speaking: "Frank is speaking"
        case .disconnected: "Frank is offline"
        case .error: "Frank needs attention"
        }
    }
}
