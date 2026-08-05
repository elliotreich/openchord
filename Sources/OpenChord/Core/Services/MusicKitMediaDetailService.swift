import Foundation
@preconcurrency import MusicKit

@MainActor
final class MusicKitMediaDetailService: MediaDetailService {
    func tracks(for item: MediaItemRef) async throws -> [MediaItemRef] {
        switch item.kind {
        case .album:
            let album = try await resolveAlbum(item)
            let detailedAlbum = try await album.with(.tracks)
            return (detailedAlbum.tracks ?? []).map { track in
                mediaItem(for: track, source: item.source)
            }
        case .playlist:
            let playlist = try await resolvePlaylist(item)
            let detailedPlaylist = try await playlist.with(.tracks)
            return (detailedPlaylist.tracks ?? []).map { track in
                mediaItem(for: track, source: item.source)
            }
        default:
            throw AppError.unsupportedAction(action: "loading tracks for a \(item.kind.rawValue)")
        }
    }

    func artistContent(for item: MediaItemRef) async throws -> ArtistDetail {
        guard item.kind == .artist else {
            throw AppError.unsupportedAction(action: "loading artist content for a \(item.kind.rawValue)")
        }

        let artist = try await resolveArtist(item)
        let detailedArtist = try await artist.with([.albums, .topSongs])
        let albums = (detailedArtist.albums ?? []).map { album in
            MediaItemRef(
                id: String(describing: album.id),
                kind: .album,
                title: album.title,
                subtitle: album.artistName,
                artworkURL: album.artwork?.url(width: 480, height: 480),
                artwork: album.artwork,
                source: item.source
            )
        }
        let topSongs = (detailedArtist.topSongs ?? []).map { song in
            MediaItemRef(
                id: String(describing: song.id),
                kind: .song,
                title: song.title,
                subtitle: song.artistName,
                artworkURL: song.artwork?.url(width: 480, height: 480),
                artwork: song.artwork,
                source: item.source
            )
        }
        return ArtistDetail(albums: albums, topSongs: topSongs)
    }

    private func resolveAlbum(_ item: MediaItemRef) async throws -> Album {
        switch item.source {
        case .catalog:
            var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(item.id))
            request.limit = 1
            guard let album = try await request.response().items.first else {
                throw AppError.musicKit(message: "The album is no longer available in the Apple Music catalog.")
            }
            return album
        case .library:
            var request = MusicLibraryRequest<Album>()
            request.limit = 1
            request.filter(matching: \.id, equalTo: MusicItemID(item.id))
            guard let album = try await request.response().items.first else {
                throw AppError.musicKit(message: "The album is no longer available in your library.")
            }
            return album
        case .local:
            throw AppError.unsupportedAction(action: "loading a local-only album")
        }
    }

    private func resolvePlaylist(_ item: MediaItemRef) async throws -> Playlist {
        switch item.source {
        case .catalog:
            var request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: MusicItemID(item.id))
            request.limit = 1
            guard let playlist = try await request.response().items.first else {
                throw AppError.musicKit(message: "The playlist is no longer available in the Apple Music catalog.")
            }
            return playlist
        case .library:
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 1
            request.filter(matching: \.id, equalTo: MusicItemID(item.id))
            guard let playlist = try await request.response().items.first else {
                throw AppError.musicKit(message: "The playlist is no longer available in your library.")
            }
            return playlist
        case .local:
            throw AppError.unsupportedAction(action: "loading a local-only playlist")
        }
    }

    private func resolveArtist(_ item: MediaItemRef) async throws -> Artist {
        switch item.source {
        case .catalog:
            var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(item.id))
            request.limit = 1
            guard let artist = try await request.response().items.first else {
                throw AppError.musicKit(message: "The artist is no longer available in the Apple Music catalog.")
            }
            return artist
        case .library:
            var request = MusicLibraryRequest<Artist>()
            request.limit = 1
            request.filter(matching: \.id, equalTo: MusicItemID(item.id))
            guard let artist = try await request.response().items.first else {
                throw AppError.musicKit(message: "The artist is no longer available in your library.")
            }
            return artist
        case .local:
            throw AppError.unsupportedAction(action: "loading a local-only artist")
        }
    }

    private func mediaItem(for track: Track, source: MediaSource) -> MediaItemRef {
        switch track {
        case .song(let song):
            MediaItemRef(
                id: String(describing: song.id),
                kind: .song,
                title: song.title,
                subtitle: song.artistName,
                artworkURL: song.artwork?.url(width: 480, height: 480),
                artwork: song.artwork,
                source: source
            )
        case .musicVideo(let musicVideo):
            MediaItemRef(
                id: String(describing: musicVideo.id),
                kind: .musicVideo,
                title: musicVideo.title,
                subtitle: musicVideo.artistName,
                artworkURL: musicVideo.artwork?.url(width: 480, height: 480),
                artwork: musicVideo.artwork,
                source: source
            )
        @unknown default:
            MediaItemRef(
                id: String(describing: track.id),
                kind: .song,
                title: track.title,
                subtitle: track.artistName,
                artworkURL: track.artwork?.url(width: 480, height: 480),
                artwork: track.artwork,
                source: source
            )
        }
    }
}
