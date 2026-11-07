import SwiftUI

struct AssistantView: View {
    @StateObject private var viewModel: AssistantViewModel

    init(viewModel: AssistantViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Frank")
                .font(.largeTitle.bold())

            Text(viewModel.state.announcement)
                .font(.title2)
                .accessibilityAddTraits(.isHeader)

            if viewModel.state == .thinking {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Frank is thinking")
            }

            Text(viewModel.detail)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if !viewModel.transcript.isEmpty {
                Text("You said: \(viewModel.transcript)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("You said \(viewModel.transcript)")
            }

            Button(viewModel.primaryButtonTitle) { viewModel.primaryAction() }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minWidth: 180, minHeight: 56)
            .accessibilityHint(viewModel.state == .listening ? "Stops recording and sends what you said" : "")

            if !viewModel.lastReply.isEmpty, !viewModel.state.isActive {
                Button("Repeat Frank") { viewModel.repeatLastResponse() }
                    .frame(minWidth: 160, minHeight: 48)
                    .accessibilityHint("Plays Frank’s last response again")
            }

            Spacer()
        }
        .padding(32)
        .animation(.default, value: viewModel.state)
        .accessibilityElement(children: .contain)
    }
}

struct AssistantView_Previews: PreviewProvider {
    static var previews: some View {
        AssistantView(viewModel: AssistantViewModel())
    }
}
