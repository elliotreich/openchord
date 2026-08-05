import Foundation
@preconcurrency import MusicKit

@MainActor
final class MusicKitPlaybackService: PlaybackService {
    private let player: ApplicationMusicPlayer
    private(set) var state = PlaybackState()

    init(player: ApplicationMusicPlayer = .shared) {
        self.player = player
    }

    func refresh() async {
        var nextState = state
        nextState.status = playbackStatus
        nextState.currentItem = player.queue.currentEntry.map(mediaItem)
        nextState.elapsed = player.playbackTime
        nextState.repeatMode = repeatMode
        nextState.shuffleEnabled = player.state.shuffleMode == .songs
        nextState.queue = player.queue.entries.map(mediaItem)
        state = nextState
    }

    func play(_ item: MediaItemRef) async throws {
        switch item.kind {
        case .song:
            player.queue = [try await resolveSong(item)]
        case .album:
            player.queue = [try await resolveAlbum(item)]
        case .playlist:
            player.queue = [try await resolvePlaylist(item)]
        case .artist:
            throw AppError.unsupportedAction(action: "playing an artist")
        case .musicVideo:
            throw AppError.unsupportedAction(action: "playing a music video")
        }

        try await player.play()
        await refresh()
    }

    func playNext(_ item: MediaItemRef) async throws {
        try await insert(item, position: .afterCurrentEntry)
        await refresh()
    }

    func addToQueue(_ item: MediaItemRef) async throws {
        try await insert(item, position: .tail)
        await refresh()
    }

    func togglePlayback() async throws {
        if player.state.playbackStatus == .playing {
            player.pause()
        } else {
            try await player.play()
        }
        await refresh()
    }

    func skipNext() async throws {
        try await player.skipToNextEntry()
        await refresh()
    }

    func skipPrevious() async throws {
        try await player.skipToPreviousEntry()
        await refresh()
    }

    func setShuffle(enabled: Bool) async {
        player.state.shuffleMode = enabled ? .songs : .off
        await refresh()
    }

    func setRepeatMode(_ mode: RepeatMode) async {
        player.state.repeatMode = switch mode {
        case .off:
            MusicPlayer.RepeatMode.none
        case .one:
            MusicPlayer.RepeatMode.one
        case .all:
            MusicPlayer.RepeatMode.all
        }
        await refresh()
    }

    private func insert(_ item: MediaItemRef, position: MusicPlayer.Queue.EntryInsertionPosition) async throws {
        switch item.kind {
        case .song:
            try await player.queue.insert(try await resolveSong(item), position: position)
        case .album:
            try await player.queue.insert(try await resolveAlbum(item), position: position)
        case .playlist:
            try await player.queue.insert(try await resolvePlaylist(item), position: position)
        case .artist:
            throw AppError.unsupportedAction(action: "queueing an artist")
        case .musicVideo:
            throw AppError.unsupportedAction(action: "queueing a music video")
        }
    }

    private func resolveSong(_ item: MediaItemRef) async throws -> Song {
        switch item.source {
        case .catalog:
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(item.id))
            request.limit = 1
            guard let song = try await request.response().items.first else {
                throw AppError.musicKit(message: "The song is no longer available in the Apple Music catalog.")
            }
            return song
        case .library:
            var request = MusicLibraryRequest<Song>()
            request.limit = 1
            request.filter(matching: \.id, equalTo: MusicItemID(item.id))
            guard let song = try await request.response().items.first else {
                throw AppError.musicKit(message: "The song is no longer available in your library.")
            }
            return song
        case .local:
            throw AppError.unsupportedAction(action: "playing a local-only reference")
        }
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
            throw AppError.unsupportedAction(action: "playing a local-only reference")
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
            throw AppError.unsupportedAction(action: "playing a local-only reference")
        }
    }

    private var playbackStatus: PlaybackStatus {
        switch player.state.playbackStatus {
        case .stopped:
            .stopped
        case .playing, .seekingForward, .seekingBackward:
            .playing
        case .paused:
            .paused
        case .interrupted:
            .interrupted
        @unknown default:
            .failed
        }
    }

    private var repeatMode: RepeatMode {
        switch player.state.repeatMode ?? .none {
        case .none:
            .off
        case .one:
            .one
        case .all:
            .all
        @unknown default:
            .off
        }
    }

    private func mediaItem(from entry: MusicPlayer.Queue.Entry) -> MediaItemRef {
        switch entry.item {
        case .song(let song):
            return MediaItemRef(
                id: String(describing: song.id),
                kind: .song,
                title: entry.title,
                subtitle: entry.subtitle ?? "",
                artworkURL: entry.artwork?.url(width: 480, height: 480),
                source: .catalog
            )
        case .musicVideo(let musicVideo):
            return MediaItemRef(
                id: String(describing: musicVideo.id),
                kind: .musicVideo,
                title: entry.title,
                subtitle: entry.subtitle ?? "",
                artworkURL: entry.artwork?.url(width: 480, height: 480),
                source: .catalog
            )
        case nil:
            return fallbackMediaItem(for: entry)
        case .some:
            return fallbackMediaItem(for: entry)
        }
    }

    private func fallbackMediaItem(for entry: MusicPlayer.Queue.Entry) -> MediaItemRef {
        MediaItemRef(
            id: entry.id,
            kind: .song,
            title: entry.title,
            subtitle: entry.subtitle ?? "",
            artworkURL: entry.artwork?.url(width: 480, height: 480),
            source: .catalog
        )
    }
}
