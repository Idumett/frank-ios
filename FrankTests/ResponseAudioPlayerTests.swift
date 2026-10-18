import XCTest
@testable import Frank

final class ResponseAudioPlayerTests: XCTestCase {
    @MainActor
    func testRejectsAnEmptyServerResponse() {
        let player = ResponseAudioPlayer()
        XCTAssertThrowsError(try player.play(Data(), finished: {})) { error in
            XCTAssertEqual(error as? ResponseAudioError, .emptyResponse)
        }
    }
}
