import Foundation

struct AppConfiguration: Equatable, Sendable {
    let serverURL: URL?
    let accessToken: String

    static let current = AppConfiguration(
        serverURL: value(named: "FRANK_SERVER_URL").flatMap(URL.init(string:)),
        accessToken: value(named: "FRANK_ACCESS_TOKEN") ?? ""
    )

    var isConfigured: Bool {
        serverURL != nil && !accessToken.isEmpty
    }

    private static func value(named key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
