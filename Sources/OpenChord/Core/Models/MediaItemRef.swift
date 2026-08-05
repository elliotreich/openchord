import Foundation

enum MediaKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case song
    case album
    case playlist
    case artist
    case musicVideo

    var id: String { rawValue }
}

enum MediaSource: String, Codable, Hashable, Sendable {
    case catalog
    case library
    case local
}

struct MediaItemRef: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let kind: MediaKind
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let source: MediaSource

    init(
        id: String,
        kind: MediaKind,
        title: String,
        subtitle: String = "",
        artworkURL: URL? = nil,
        source: MediaSource
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.source = source
    }
}

struct MusicSearchQuery: Hashable, Sendable {
    let term: String
    let scope: MusicSearchScope
    let kinds: Set<MediaKind>

    init(
        term: String,
        scope: MusicSearchScope = .both,
        kinds: Set<MediaKind> = Set(MediaKind.allCases)
    ) {
        self.term = term
        self.scope = scope
        self.kinds = kinds
    }
}

enum MusicSearchScope: String, CaseIterable, Codable, Hashable, Sendable {
    case library
    case catalog
    case both
}
