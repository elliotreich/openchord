import Foundation

@MainActor
final class MockAuthorizationService: AuthorizationService {
    private(set) var state = AuthorizationState(
        isAuthorized: true,
        hasSubscription: true,
        hasCloudLibrary: true,
        lastDiagnosticMessage: "Preview authorization"
    )

    func refresh() async {}

    func requestAuthorization() async {
        state.isAuthorized = true
    }
}

@MainActor
final class MockCatalogService: CatalogService {
    private let items: [MediaItemRef] = [
        MediaItemRef(id: "catalog-song-1", kind: .song, title: "Preview Song", subtitle: "Preview Artist", source: .catalog),
        MediaItemRef(id: "catalog-album-1", kind: .album, title: "Preview Album", subtitle: "Preview Artist", source: .catalog),
        MediaItemRef(id: "catalog-playlist-1", kind: .playlist, title: "Preview Playlist", subtitle: "OpenChord", source: .catalog),
        MediaItemRef(id: "catalog-artist-1", kind: .artist, title: "Preview Artist", subtitle: "Apple Music artist", source: .catalog)
    ]

    func search(_ query: MusicSearchQuery) async throws -> [MediaItemRef] {
        let term = query.term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return items.filter { item in
            query.kinds.contains(item.kind) &&
            (item.title.localizedCaseInsensitiveContains(term) || item.subtitle.localizedCaseInsensitiveContains(term))
        }
    }

    func items(for sectionID: String, limit: Int) async throws -> [MediaItemRef] {
        let matchingItems: [MediaItemRef]
        switch sectionID {
        case "topSongs":
            matchingItems = items.filter { $0.kind == .song }
        case "topAlbums":
            matchingItems = items.filter { $0.kind == .album }
        case "topPlaylists":
            matchingItems = items.filter { $0.kind == .playlist }
        default:
            throw AppError.unsupportedAction(action: "loading catalog section (sectionID)")
        }
        return Array(matchingItems.prefix(max(0, limit)))
    }
}

@MainActor
final class MockLibraryService: LibraryService {
    private let items: [MediaItemRef] = [
        MediaItemRef(id: "library-song-1", kind: .song, title: "Library Song", subtitle: "Library Artist", source: .library),
        MediaItemRef(id: "library-album-1", kind: .album, title: "Library Album", subtitle: "Library Artist", source: .library),
        MediaItemRef(id: "library-playlist-1", kind: .playlist, title: "Library Playlist", subtitle: "Library", source: .library),
        MediaItemRef(id: "library-artist-1", kind: .artist, title: "Library Artist", subtitle: "Library artist", source: .library)
    ]

    func search(_ query: MusicSearchQuery) async throws -> [MediaItemRef] {
        let term = query.term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return items.filter { item in
            query.kinds.contains(item.kind) &&
            (item.title.localizedCaseInsensitiveContains(term) || item.subtitle.localizedCaseInsensitiveContains(term))
        }
    }

    func items(kind: MediaKind, limit: Int, downloadedOnly: Bool) async throws -> [MediaItemRef] {
        Array(items.filter { $0.kind == kind }.prefix(max(0, limit)))
    }

    func items(for sectionID: String, limit: Int, downloadedOnly: Bool) async throws -> [MediaItemRef] {
        let kind: MediaKind
        switch sectionID {
        case "recentlyPlayed", "recentlyAdded":
            kind = .song
        case "playlists":
            kind = .playlist
        case "albums":
            kind = .album
        default:
            throw AppError.unsupportedAction(action: "loading library section (sectionID)")
        }
        return try await items(kind: kind, limit: limit, downloadedOnly: downloadedOnly)
    }
}

@MainActor
final class MockMediaDetailService: MediaDetailService {
    func tracks(for item: MediaItemRef) async throws -> [MediaItemRef] {
        guard item.kind == .album || item.kind == .playlist else {
            throw AppError.unsupportedAction(action: "loading tracks for a (item.kind.rawValue)")
        }

        return (1...3).map { index in
            MediaItemRef(
                id: "\(item.id)-track-\(index)",
                kind: .song,
                title: "\(item.title) Track \(index)",
                subtitle: item.subtitle,
                source: item.source
            )
        }
    }

    func artistContent(for item: MediaItemRef) async throws -> ArtistDetail {
        guard item.kind == .artist else {
            throw AppError.unsupportedAction(action: "loading artist content for a \(item.kind.rawValue)")
        }

        let album = MediaItemRef(
            id: "\(item.id)-album-1",
            kind: .album,
            title: "Preview Album",
            subtitle: item.title,
            source: item.source
        )
        let song = MediaItemRef(
            id: "\(item.id)-song-1",
            kind: .song,
            title: "Preview Top Song",
            subtitle: item.title,
            source: item.source
        )
        return ArtistDetail(albums: [album], topSongs: [song])
    }
}

@MainActor
final class MockPlaybackService: PlaybackService {
    private(set) var state = PlaybackState()

    func refresh() async {}

    func play(_ item: MediaItemRef) async throws {
        state.currentItem = item
        state.status = .playing
        if !state.queue.contains(item) {
            state.queue = [item] + state.queue
        }
    }

    func playNext(_ item: MediaItemRef) async throws {
        state.queue.insert(item, at: min(1, state.queue.count))
    }

    func addToQueue(_ item: MediaItemRef) async throws {
        state.queue.append(item)
    }

    func togglePlayback() async throws {
        state.status = state.status == .playing ? .paused : .playing
    }

    func skipNext() async throws {
        guard state.queue.count > 1 else {
            state.status = .stopped
            return
        }
        state.queue.removeFirst()
        state.currentItem = state.queue.first
    }

    func skipPrevious() async throws {}

    func setShuffle(enabled: Bool) async {
        state.shuffleEnabled = enabled
    }

    func setRepeatMode(_ mode: RepeatMode) async {
        state.repeatMode = mode
    }
}
