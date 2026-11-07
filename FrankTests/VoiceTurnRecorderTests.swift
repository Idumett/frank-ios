import XCTest
@testable import Frank

@MainActor
private final class RecorderMicrophone: MicrophoneCapturing {
    private(set) var isRecording = false
    private var onChunk: (@Sendable (CapturedAudioChunk) -> Void)?

    func requestPermission() async -> Bool { true }
    func start(onChunk: @escaping @Sendable (CapturedAudioChunk) -> Void) throws {
        isRecording = true
        self.onChunk = onChunk
    }
    func stop() { isRecording = false }
    func emit(_ chunk: CapturedAudioChunk) { onChunk?(chunk) }
}

private actor RecordedPayload {
    private var data: Data?
    func save(_ data: Data) { self.data = data }
    func value() -> Data? { data }
}

final class VoiceTurnRecorderTests: XCTestCase {
    @MainActor
    func testManualFinishStopsRecordingAndSendsTheBufferedTurn() async throws {
        let microphone = RecorderMicrophone()
        let payload = RecordedPayload()
        let sent = expectation(description: "audio sent")
        let recorder = VoiceTurnRecorder(microphone: microphone) { data in
            await payload.save(data)
        }
        recorder.onResult = { result in
            if result == .sent { sent.fulfill() }
        }

        await recorder.start()
        microphone.emit(.init(samples: Array(repeating: 0.08, count: 4_800), sampleRate: 16_000))
        await Task.yield()
        recorder.finish()
        await fulfillment(of: [sent], timeout: 1)

        XCTAssertFalse(microphone.isRecording)
        let capturedPayload = await payload.value()
        let data = try XCTUnwrap(capturedPayload)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
    }
}
