import XCTest
@testable import Frank

final class PreparedCameraTests: XCTestCase {
    func testSelectsTheNewestFreshUsableFrame() async {
        let store = PreparedFrameStore(capacity: 3)
        let now = Date()
        await store.add(.init(id: "old", jpeg: Data([1]), capturedAt: now.addingTimeInterval(-4), quality: .good))
        await store.add(.init(id: "poor", jpeg: Data([2]), capturedAt: now, quality: .poor))
        await store.add(.init(id: "fresh", jpeg: Data([3]), capturedAt: now.addingTimeInterval(-0.2), quality: .good))

        let selected = await store.freshest(maxAgeMs: 1_000, now: now)
        XCTAssertEqual(selected?.id, "fresh")
    }

    func testRefusesAnExpiredFrame() async {
        let store = PreparedFrameStore()
        let now = Date()
        await store.add(.init(id: "old", jpeg: Data([1]), capturedAt: now.addingTimeInterval(-2), quality: .good))
        let selected = await store.freshest(maxAgeMs: 500, now: now)
        XCTAssertNil(selected)
    }
}
