import SwiftUI

@main
struct FrankApp: App {
    private let viewModel: AssistantViewModel

    init() {
        let transport = ReconnectingTransport(transport: FrankWebSocketTransport())
        let session = AssistantSession(transport: transport)
        viewModel = AssistantViewModel(
            session: session,
            microphone: MicrophoneRecorder(),
            audioPlayer: ResponseAudioPlayer(),
            audioSession: AudioSessionController(),
            camera: PreparedCamera(),
            contextEngine: ContextEngine()
        )
    }

    var body: some Scene {
        WindowGroup {
            AssistantView(viewModel: viewModel)
        }
    }
}
