import XCTest
@testable import Frank

final class AssistantStateTests: XCTestCase {
    func testStateAnnouncementsAreUserFacing() {
        XCTAssertEqual(AssistantState.listening.announcement, "Listening")
        XCTAssertEqual(AssistantState.disconnected.announcement, "Frank is offline")
    }
}
