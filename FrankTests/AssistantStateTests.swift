import XCTest
@testable import Frank

final class AssistantStateTests: XCTestCase {
    func testOnlyLiveTurnStatesAreActive() {
        XCTAssertTrue(AssistantState.listening.isActive)
        XCTAssertTrue(AssistantState.thinking.isActive)
        XCTAssertTrue(AssistantState.speaking.isActive)
        XCTAssertFalse(AssistantState.ready.isActive)
        XCTAssertFalse(AssistantState.error.isActive)
    }
    func testStateAnnouncementsAreUserFacing() {
        XCTAssertEqual(AssistantState.listening.announcement, "Listening")
        XCTAssertEqual(AssistantState.disconnected.announcement, "Frank is offline")
    }
}
