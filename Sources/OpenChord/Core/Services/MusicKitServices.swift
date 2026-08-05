import Foundation
@preconcurrency import MusicKit

@MainActor
final class MusicKitAuthorizationService: AuthorizationService {
    private(set) var state = AuthorizationState()

    func refresh() async {
        let status = MusicAuthorization.currentStatus
        state.isAuthorized = status == .authorized
        state.hasSubscription = nil
        state.hasCloudLibrary = nil
        state.lastDiagnosticMessage = String(describing: status)

        guard state.isAuthorized else { return }

        do {
            let subscription = try await MusicSubscription.current
            state.hasSubscription = subscription.canPlayCatalogContent
            state.hasCloudLibrary = subscription.hasCloudLibraryEnabled
            state.lastDiagnosticMessage = subscription.description
        } catch {
            state.lastDiagnosticMessage = "(status): (error.localizedDescription)"
        }
    }

    func requestAuthorization() async {
        _ = await MusicAuthorization.request()
        await refresh()
    }
}

@MainActor
final class MusicKitCatalogService: CatalogService {
    func search(_ query: MusicSearchQuery) async throws -> [MediaItemRef] {
        let term = query.term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            throw AppError.invalidInput(message: "Search text cannot be empty.")
        }

        let request = MusicCatalogSearchRequest(
            term: term,
            types: [Song.self, Album.self, Playlist.self, Artist.self]
        )
        let response = try await request.response()
        var results: [MediaItemRef] = []

        if query.kinds.contains(.song) {
            results += response.songs.map { song in
                MediaItemRef(
                    id: String(describing: song.id),
                    kind: .song,
                    title: song.title,
                    subtitle: [song.artistName, song.albumTitle].compactMap { $0 }.joined(separator: " • "),
                    artworkURL: song.artwork?.url(width: 480, height: 480),
                    source: .catalog
                )
            }
        }
        if query.kinds.contains(.album) {
            results += response.albums.map { album in
                MediaItemRef(
                    id: String(describing: album.id),
                    kind: .album,
                    title: album.title,
                    subtitle: album.artistName,
                    artworkURL: album.artwork?.url(width: 480, height: 480),
                    source: .catalog
                )
            }
        }
        if query.kinds.contains(.playlist) {
            results += response.playlists.map { playlist in
                MediaItemRef(
                    id: String(describing: playlist.id),
                    kind: .playlist,
                    title: playlist.name,
                    subtitle: playlist.curatorName ?? "Apple Music",
                    artworkURL: playlist.artwork?.url(width: 480, height: 480),
                    source: .catalog
                )
            }
        }
        if query.kinds.contains(.artist) {
            results += response.artists.map { artist in
                MediaItemRef(
                    id: String(describing: artist.id),
                    kind: .artist,
                    title: artist.name,
                    subtitle: "Apple Music artist",
                    artworkURL: artist.artwork?.url(width: 480, height: 480),
                    source: .catalog
                )
            }
        }

        return results
    }

    func items(for sectionID: String, limit: Int) async throws -> [MediaItemRef] {
        throw AppError.unsupportedAction(action: "catalog section \(sectionID)")
    }
}

@MainActor
final class MusicKitLibraryService: LibraryService {
    func search(_ query: MusicSearchQuery) async throws -> [MediaItemRef] {
        let term = query.term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            throw AppError.invalidInput(message: "Search text cannot be empty.")
        }

        let request = MusicLibrarySearchRequest(
            term: term,
            types: [Song.self, Album.self, Playlist.self, Artist.self]
        )
        let response = try await request.response()
        var results: [MediaItemRef] = []

        if query.kinds.contains(.song) {
            results += response.songs.map { song in
                MediaItemRef(
                    id: String(describing: song.id),
                    kind: .song,
                    title: song.title,
                    subtitle: [song.artistName, song.albumTitle].compactMap { $0 }.joined(separator: " • "),
                    artworkURL: song.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        }
        if query.kinds.contains(.album) {
            results += response.albums.map { album in
                MediaItemRef(
                    id: String(describing: album.id),
                    kind: .album,
                    title: album.title,
                    subtitle: album.artistName,
                    artworkURL: album.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        }
        if query.kinds.contains(.playlist) {
            results += response.playlists.map { playlist in
                MediaItemRef(
                    id: String(describing: playlist.id),
                    kind: .playlist,
                    title: playlist.name,
                    subtitle: playlist.curatorName ?? "Library",
                    artworkURL: playlist.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        }
        if query.kinds.contains(.artist) {
            results += response.artists.map { artist in
                MediaItemRef(
                    id: String(describing: artist.id),
                    kind: .artist,
                    title: artist.name,
                    subtitle: "Library artist",
                    artworkURL: artist.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        }

        return results
    }

    func items(kind: MediaKind, limit: Int, downloadedOnly: Bool) async throws -> [MediaItemRef] {
        switch kind {
        case .song:
            var request = MusicLibraryRequest<Song>()
            request.limit = limit
            request.includeOnlyDownloadedContent = downloadedOnly
            request.sort(by: \.libraryAddedDate, ascending: false)
            return try await request.response().items.map { song in
                MediaItemRef(
                    id: String(describing: song.id),
                    kind: .song,
                    title: song.title,
                    subtitle: song.artistName,
                    artworkURL: song.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        case .album:
            var request = MusicLibraryRequest<Album>()
            request.limit = limit
            request.includeOnlyDownloadedContent = downloadedOnly
            request.sort(by: \.libraryAddedDate, ascending: false)
            return try await request.response().items.map { album in
                MediaItemRef(
                    id: String(describing: album.id),
                    kind: .album,
                    title: album.title,
                    subtitle: album.artistName,
                    artworkURL: album.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        case .playlist:
            var request = MusicLibraryRequest<Playlist>()
            request.limit = limit
            request.includeOnlyDownloadedContent = downloadedOnly
            request.sort(by: \.libraryAddedDate, ascending: false)
            return try await request.response().items.map { playlist in
                MediaItemRef(
                    id: String(describing: playlist.id),
                    kind: .playlist,
                    title: playlist.name,
                    subtitle: playlist.curatorName ?? "Library",
                    artworkURL: playlist.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        case .artist:
            var request = MusicLibraryRequest<Artist>()
            request.limit = limit
            request.includeOnlyDownloadedContent = downloadedOnly
            request.sort(by: \.libraryAddedDate, ascending: false)
            return try await request.response().items.map { artist in
                MediaItemRef(
                    id: String(describing: artist.id),
                    kind: .artist,
                    title: artist.name,
                    subtitle: "Library artist",
                    artworkURL: artist.artwork?.url(width: 480, height: 480),
                    source: .library
                )
            }
        case .musicVideo:
            throw AppError.unsupportedAction(action: "library music-video browsing")
        }
    }
}
