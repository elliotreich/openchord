import Foundation

struct FeatureFlags: Codable, Equatable, Sendable {
    var libraryBrowser = true
    var richDetails = true
    var universalSearch = true
    var fullPlayer = false
    var systemPlayer = false
    var magicMix = false
    var lyrics = false
    var scrobbling = false

    static let `default` = FeatureFlags()
}
