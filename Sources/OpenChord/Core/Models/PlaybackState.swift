import Foundation

enum PlaybackStatus: String, Codable, Hashable, Sendable {
    case stopped
    case playing
    case paused
    case interrupted
    case failed
}

enum PlayerKind: String, CaseIterable, Codable, Hashable, Sendable {
    case application
    case system
}

enum RepeatMode: String, CaseIterable, Codable, Hashable, Sendable {
    case off
    case one
    case all
}

struct PlaybackState: Codable, Equatable, Sendable {
    var playerKind: PlayerKind = .application
    var status: PlaybackStatus = .stopped
    var currentItem: MediaItemRef?
    var elapsed: TimeInterval = 0
    var duration: TimeInterval = 0
    var repeatMode: RepeatMode = .off
    var shuffleEnabled = false
    var queue: [MediaItemRef] = []
}
