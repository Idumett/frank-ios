import Combine
import Foundation

@MainActor
final class AssistantViewModel: ObservableObject {
    @Published private(set) var state: AssistantState = .ready
    @Published private(set) var detail = "Tap the button and speak naturally."

    func beginListening() {
        state = .listening
        detail = "I’m listening."
    }

    func stop() {
        state = .ready
        detail = "Tap the button and speak naturally."
    }
}
