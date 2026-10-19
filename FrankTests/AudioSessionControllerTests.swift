import AVFoundation
import XCTest
@testable import Frank

final class AudioSessionControllerTests: XCTestCase {
    func testReadsAnInterruptionThatCanResume() {
        let info: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
        XCTAssertEqual(AudioSessionController.interruption(from: info), .interruptionEnded(shouldResume: true))
    }

    func testTreatsAnOpeningInterruptionAsStoppedAudio() {
        let info: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
        ]
        XCTAssertEqual(AudioSessionController.interruption(from: info), .interrupted)
    }
}
