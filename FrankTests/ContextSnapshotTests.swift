import XCTest
@testable import Frank

final class ContextSnapshotTests: XCTestCase {
    func testUnknownAndDeniedHaveDifferentWireStates() throws {
        let source = ContextProvenance(source: .system, collectedAt: "2026-10-20T10:00:00Z")
        let values: [ContextValue<String>] = [
            .unknown(reason: "not_collected", provenance: source),
            .denied(permission: "location", provenance: source)
        ]
        let data = try JSONEncoder().encode(values)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("unknown"))
        XCTAssertTrue(text.contains("denied"))
        XCTAssertTrue(text.contains("location"))
    }
}
