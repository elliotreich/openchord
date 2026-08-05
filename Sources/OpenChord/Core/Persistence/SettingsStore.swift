import Foundation

struct SettingsStore {
    static let legacyKey = "OpenChord.persistedState"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func readLegacyPayload() -> Data? {
        defaults.data(forKey: Self.legacyKey)
    }

    func decodeLegacy<T: Decodable>(_ type: T.Type) -> T? {
        guard let payload = readLegacyPayload() else { return nil }
        return try? JSONDecoder().decode(type, from: payload)
    }

    func writeLegacyPayload(_ payload: Data) {
        defaults.set(payload, forKey: Self.legacyKey)
    }
}
