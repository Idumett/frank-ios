import SwiftUI

@main
struct FrankApp: App {
    var body: some Scene {
        WindowGroup {
            AssistantView(viewModel: AssistantViewModel())
        }
    }
}
