import Foundation
@preconcurrency import MusicKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var selectedSection: AppSection = .home
    @Published var searchText: String = ""
    @Published var librarySearchText: String = ""
    @Published var isBusy = false
    @Published var lastErrorMessage: String?
    @Published var catalogResults = SearchResults()
    @Published var libraryResults = SearchResults()
    @Published var queueSnapshot = QueueSnapshot()
    @Published var homeSections: [HomeSectionKind]
    @Published var theme: AppTheme
    @Published var queueShuffleEnabled = false
    @Published var queueRepeatMode: MusicPlayer.RepeatMode = .none
    @Published var recentSearches: [String]
    @Published var libraryBrowse = LibraryBrowseSnapshot()
    @Published var libraryBrowseDownloadedOnly = false

    private nonisolated(unsafe) let player = ApplicationMusicPlayer.shared
    private let settingsStore = SettingsStore()

    init() {
        let persisted = Self.loadPersistedState(from: settingsStore.readLegacyPayload())
        self.homeSections = persisted?.homeSections ?? HomeSectionKind.defaultOrder
        self.theme = persisted?.theme ?? .midnight
        self.queueShuffleEnabled = persisted?.queueShuffleEnabled ?? false
        self.queueRepeatMode = persisted?.queueRepeatMode.musicKitValue ?? .none
        self.recentSearches = persisted?.recentSearches ?? []
        self.libraryBrowseDownloadedOnly = persisted?.libraryBrowseDownloadedOnly ?? false

        Task {
            await refreshAuthorization()
            await refreshPlaybackSnapshot()
            await loadLibraryBrowse()
        }
    }

    func refreshAuthorization() async {
        authorizationStatus = MusicAuthorization.currentStatus
        guard authorizationStatus == .notDetermined else { return }
        authorizationStatus = await MusicAuthorization.request()
    }

    func requestAuthorization() async {
        authorizationStatus = await MusicAuthorization.request()
    }

    func refreshPlaybackSnapshot() async {
        let entries = player.queue.entries.map { entry in
            QueueEntrySnapshot(
                id: entry.id,
                title: entry.title,
                subtitle: entry.subtitle ?? "",
                artworkURL: entry.artwork?.url(width: 240, height: 240)
            )
        }

        queueSnapshot = QueueSnapshot(
            statusText: String(describing: player.state.playbackStatus).capitalized,
            currentTitle: player.queue.currentEntry?.title ?? "Nothing playing",
            currentArtist: player.queue.currentEntry?.subtitle ?? "Connect Apple Music",
            currentArtworkURL: player.queue.currentEntry?.artwork?.url(width: 160, height: 160),
            entries: entries
        )
    }

    func performCatalogSearch() async {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            catalogResults = SearchResults()
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let request = MusicCatalogSearchRequest(term: term, types: [Song.self, Album.self, Playlist.self, Artist.self])
            let response = try await request.response()
            catalogResults = SearchResults(
                songs: response.songs.map { .song($0, source: .catalog) },
                albums: response.albums.map { .album($0, source: .catalog) },
                playlists: response.playlists.map { .playlist($0, source: .catalog) },
                artists: response.artists.map { .artist($0, source: .catalog) }
            )
            recordRecentSearch(term)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func performLibrarySearch() async {
        let term = librarySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            libraryResults = SearchResults()
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let request = MusicLibrarySearchRequest(term: term, types: [Song.self, Album.self, Playlist.self, Artist.self])
            let response = try await request.response()
            libraryResults = SearchResults(
                songs: response.songs.map { .song($0, source: .library) },
                albums: response.albums.map { .album($0, source: .library) },
                playlists: response.playlists.map { .playlist($0, source: .library) },
                artists: response.artists.map { .artist($0, source: .library) }
            )
            recordRecentSearch(term)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func play(_ hit: SearchHit) async {
        do {
            switch hit {
            case .song(let song, _):
                player.queue = [song]
            case .album(let album, _):
                player.queue = [album]
            case .playlist(let playlist, _):
                player.queue = [playlist]
            case .artist:
                searchText = hit.title
                await performCatalogSearch()
                return
            }

            try await player.play()
            queueShuffleEnabled = (player.state.shuffleMode ?? .off) == .songs
            queueRepeatMode = player.state.repeatMode ?? .none
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func playNext(_ hit: SearchHit) async {
        await queue(hit, position: .afterCurrentEntry)
    }

    func addToQueue(_ hit: SearchHit) async {
        await queue(hit, position: .tail)
    }

    func play(_ track: Track) async {
        do {
            player.queue = [track]
            try await player.play()
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func playNext(_ track: Track) async {
        await queue(track, position: .afterCurrentEntry)
    }

    func addToQueue(_ track: Track) async {
        await queue(track, position: .tail)
    }

    func clearRecentSearches() {
        recentSearches.removeAll()
        persistSettings()
    }

    func setLibraryBrowseDownloadedOnly(_ newValue: Bool) {
        libraryBrowseDownloadedOnly = newValue
        persistSettings()
        Task { await loadLibraryBrowse() }
    }

    func playPause() async {
        do {
            if player.state.playbackStatus == .playing {
                player.pause()
            } else {
                try await player.play()
            }
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func skipNext() async {
        do {
            try await player.skipToNextEntry()
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func skipPrevious() async {
        do {
            try await player.skipToPreviousEntry()
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func toggleShuffle() async {
        player.state.shuffleMode = queueShuffleEnabled ? .off : .songs
        queueShuffleEnabled.toggle()
        await refreshPlaybackSnapshot()
    }

    func cycleRepeatMode() async {
        queueRepeatMode = switch queueRepeatMode {
        case .none: .all
        case .all: .one
        case .one: .none
        @unknown default: .none
        }
        player.state.repeatMode = queueRepeatMode
        await refreshPlaybackSnapshot()
    }

    func toggleHomeSection(_ section: HomeSectionKind) {
        if let index = homeSections.firstIndex(of: section) {
            homeSections.remove(at: index)
        } else {
            homeSections.append(section)
        }
        persistSettings()
    }

    func moveHomeSection(from offsets: IndexSet, to destination: Int) {
        homeSections.move(fromOffsets: offsets, toOffset: destination)
        persistSettings()
    }

    func updateTheme(_ newTheme: AppTheme) {
        theme = newTheme
        persistSettings()
    }

    func updateQueueDefaults(shuffle: Bool, repeatMode: MusicPlayer.RepeatMode) {
        queueShuffleEnabled = shuffle
        queueRepeatMode = repeatMode
        player.state.shuffleMode = shuffle ? .songs : .off
        player.state.repeatMode = repeatMode
        persistSettings()
    }

    func refreshAll() async {
        await refreshAuthorization()
        await refreshPlaybackSnapshot()
        await performCatalogSearch()
        await performLibrarySearch()
        await loadLibraryBrowse()
    }

    func loadLibraryBrowse() async {
        let downloadedOnly = libraryBrowseDownloadedOnly
        libraryBrowse.isLoading = true
        defer { libraryBrowse.isLoading = false }

        async let songsTask = loadLibraryItems(Song.self, limit: 10, downloadedOnly: downloadedOnly) { request in
            request.sort(by: \.libraryAddedDate, ascending: false)
        }
        async let albumsTask = loadLibraryItems(Album.self, limit: 10, downloadedOnly: downloadedOnly) { request in
            request.sort(by: \.libraryAddedDate, ascending: false)
        }
        async let playlistsTask = loadLibraryItems(Playlist.self, limit: 10, downloadedOnly: downloadedOnly) { request in
            request.sort(by: \.libraryAddedDate, ascending: false)
        }
        async let artistsTask = loadLibraryItems(Artist.self, limit: 10, downloadedOnly: downloadedOnly) { request in
            request.sort(by: \.libraryAddedDate, ascending: false)
        }

        let songs = (try? await songsTask) ?? []
        let albums = (try? await albumsTask) ?? []
        let playlists = (try? await playlistsTask) ?? []
        let artists = (try? await artistsTask) ?? []

        libraryBrowse = LibraryBrowseSnapshot(
            songs: songs.map { .song($0, source: .library) },
            albums: albums.map { .album($0, source: .library) },
            playlists: playlists.map { .playlist($0, source: .library) },
            artists: artists.map { .artist($0, source: .library) },
            downloadedOnly: downloadedOnly,
            lastUpdated: Date()
        )
    }

    private func queue(_ hit: SearchHit, position: MusicPlayer.Queue.EntryInsertionPosition) async {
        do {
            switch hit {
            case .song(let song, _):
                try await player.queue.insert([song], position: position)
            case .album(let album, _):
                try await player.queue.insert([album], position: position)
            case .playlist(let playlist, _):
                try await player.queue.insert([playlist], position: position)
            case .artist:
                searchText = hit.title
                await performCatalogSearch()
                return
            }
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func queue(_ track: Track, position: MusicPlayer.Queue.EntryInsertionPosition) async {
        do {
            try await player.queue.insert(track, position: position)
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func loadLibraryItems<Item: MusicLibraryRequestable>(
        _ type: Item.Type,
        limit: Int,
        downloadedOnly: Bool,
        configure: (inout MusicLibraryRequest<Item>) -> Void
    ) async throws -> [Item] {
        var request = MusicLibraryRequest<Item>()
        request.limit = limit
        request.includeOnlyDownloadedContent = downloadedOnly
        configure(&request)
        return try await request.response().items.map { $0 }
    }

    private func recordRecentSearch(_ term: String) {
        let cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        recentSearches.removeAll(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame })
        recentSearches.insert(cleaned, at: 0)
        if recentSearches.count > 12 {
            recentSearches = Array(recentSearches.prefix(12))
        }
        persistSettings()
    }

    private func persistSettings() {
        let state = PersistedState(
            homeSections: homeSections,
            theme: theme,
            queueShuffleEnabled: queueShuffleEnabled,
            queueRepeatMode: queueRepeatMode,
            recentSearches: recentSearches,
            libraryBrowseDownloadedOnly: libraryBrowseDownloadedOnly
        )

        do {
            let data = try JSONEncoder().encode(state)
            settingsStore.writeLegacyPayload(data)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private static func loadPersistedState(from data: Data?) -> PersistedState? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }
}

private struct PersistedState: Codable {
    var homeSections: [HomeSectionKind]
    var theme: AppTheme
    var queueShuffleEnabled: Bool
    var queueRepeatMode: QueueRepeatModeCodable
    var recentSearches: [String]
    var libraryBrowseDownloadedOnly: Bool

    init(homeSections: [HomeSectionKind], theme: AppTheme, queueShuffleEnabled: Bool, queueRepeatMode: MusicPlayer.RepeatMode, recentSearches: [String], libraryBrowseDownloadedOnly: Bool) {
        self.homeSections = homeSections
        self.theme = theme
        self.queueShuffleEnabled = queueShuffleEnabled
        self.queueRepeatMode = QueueRepeatModeCodable(queueRepeatMode)
        self.recentSearches = recentSearches
        self.libraryBrowseDownloadedOnly = libraryBrowseDownloadedOnly
    }

    enum CodingKeys: String, CodingKey {
        case homeSections
        case theme
        case queueShuffleEnabled
        case queueRepeatMode
        case recentSearches
        case libraryBrowseDownloadedOnly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeSections = try container.decode([HomeSectionKind].self, forKey: .homeSections)
        theme = try container.decode(AppTheme.self, forKey: .theme)
        queueShuffleEnabled = try container.decode(Bool.self, forKey: .queueShuffleEnabled)
        queueRepeatMode = try container.decode(QueueRepeatModeCodable.self, forKey: .queueRepeatMode)
        recentSearches = try container.decodeIfPresent([String].self, forKey: .recentSearches) ?? []
        libraryBrowseDownloadedOnly = try container.decodeIfPresent(Bool.self, forKey: .libraryBrowseDownloadedOnly) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(homeSections, forKey: .homeSections)
        try container.encode(theme, forKey: .theme)
        try container.encode(queueShuffleEnabled, forKey: .queueShuffleEnabled)
        try container.encode(queueRepeatMode, forKey: .queueRepeatMode)
        try container.encode(recentSearches, forKey: .recentSearches)
        try container.encode(libraryBrowseDownloadedOnly, forKey: .libraryBrowseDownloadedOnly)
    }
}

private struct QueueRepeatModeCodable: Codable {
    let rawValue: String

    init(_ repeatMode: MusicPlayer.RepeatMode) {
        switch repeatMode {
        case .none:
            rawValue = "none"
        case .one:
            rawValue = "one"
        case .all:
            rawValue = "all"
        @unknown default:
            rawValue = "none"
        }
    }

    var musicKitValue: MusicPlayer.RepeatMode {
        switch rawValue {
        case "one":
            return .one
        case "all":
            return .all
        default:
            return .none
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct SearchResults {
    var songs: [SearchHit] = []
    var albums: [SearchHit] = []
    var playlists: [SearchHit] = []
    var artists: [SearchHit] = []

    var isEmpty: Bool {
        songs.isEmpty && albums.isEmpty && playlists.isEmpty && artists.isEmpty
    }

    var totalCount: Int {
        songs.count + albums.count + playlists.count + artists.count
    }
}

enum SearchSource: String, Codable, Hashable {
    case catalog
    case library

    var label: String {
        switch self {
        case .catalog:
            return "Apple Music"
        case .library:
            return "Library"
        }
    }
}

enum SearchHit: Hashable, Identifiable {
    case song(Song, source: SearchSource)
    case album(Album, source: SearchSource)
    case playlist(Playlist, source: SearchSource)
    case artist(Artist, source: SearchSource)

    var id: String {
        switch self {
        case .song(let song, let source):
            return "\(source.rawValue)-song-\(String(describing: song.id))"
        case .album(let album, let source):
            return "\(source.rawValue)-album-\(String(describing: album.id))"
        case .playlist(let playlist, let source):
            return "\(source.rawValue)-playlist-\(String(describing: playlist.id))"
        case .artist(let artist, let source):
            return "\(source.rawValue)-artist-\(String(describing: artist.id))"
        }
    }

    var source: SearchSource {
        switch self {
        case .song(_, let source), .album(_, let source), .playlist(_, let source), .artist(_, let source):
            return source
        }
    }

    var title: String {
        switch self {
        case .song(let song, _):
            return song.title
        case .album(let album, _):
            return album.title
        case .playlist(let playlist, _):
            return playlist.name
        case .artist(let artist, _):
            return artist.name
        }
    }

    var subtitle: String {
        switch self {
        case .song(let song, _):
            return [song.artistName, song.albumTitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
        case .album(let album, _):
            return album.artistName
        case .playlist(let playlist, _):
            return playlist.curatorName ?? source.label
        case .artist(_, let source):
            return source.label + " artist"
        }
    }

    var artworkURL: URL? {
        switch self {
        case .song(let song, _):
            return song.artwork?.url(width: 480, height: 480)
        case .album(let album, _):
            return album.artwork?.url(width: 480, height: 480)
        case .playlist(let playlist, _):
            return playlist.artwork?.url(width: 480, height: 480)
        case .artist(let artist, _):
            return artist.artwork?.url(width: 480, height: 480)
        }
    }

    var symbolName: String {
        switch self {
        case .song:
            return "music.note"
        case .album:
            return "square.stack"
        case .playlist:
            return "music.note.list"
        case .artist:
            return "person.crop.square"
        }
    }

    var playableDescription: String {
        switch self {
        case .song:
            return "Song"
        case .album:
            return "Album"
        case .playlist:
            return "Playlist"
        case .artist:
            return "Artist"
        }
    }

    var isPlayable: Bool {
        if case .artist = self { return false }
        return true
    }
}

struct QueueSnapshot {
    var statusText = "Stopped"
    var currentTitle = "Nothing playing"
    var currentArtist = "Connect Apple Music"
    var currentArtworkURL: URL? = nil
    var entries: [QueueEntrySnapshot] = []
}

struct LibraryBrowseSnapshot {
    var songs: [SearchHit] = []
    var albums: [SearchHit] = []
    var playlists: [SearchHit] = []
    var artists: [SearchHit] = []
    var downloadedOnly = false
    var isLoading = false
    var lastUpdated: Date?

    var totalCount: Int {
        songs.count + albums.count + playlists.count + artists.count
    }
}

struct QueueEntrySnapshot: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
}

enum AppSection: String, CaseIterable, Identifiable, Codable {
    case home
    case search
    case library
    case queue
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .search:
            return "Search"
        case .library:
            return "Library"
        case .queue:
            return "Queue"
        case .settings:
            return "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .home:
            return "house.fill"
        case .search:
            return "magnifyingglass"
        case .library:
            return "music.note.list"
        case .queue:
            return "text.line.first.and.arrowtriangle.forward"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

enum HomeSectionKind: String, CaseIterable, Identifiable, Codable {
    case spotlight
    case shortcuts
    case queuePeek
    case librarySnapshot
    case appStatus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotlight:
            return "Spotlight"
        case .shortcuts:
            return "Quick Actions"
        case .queuePeek:
            return "Queue Peek"
        case .librarySnapshot:
            return "Library Snapshot"
        case .appStatus:
            return "Status"
        }
    }

    var subtitle: String {
        switch self {
        case .spotlight:
            return "Search and play with one surface."
        case .shortcuts:
            return "Jump straight to common queries."
        case .queuePeek:
            return "See what is queued next."
        case .librarySnapshot:
            return "Check your latest search results."
        case .appStatus:
            return "Theme and authorization details."
        }
    }

    var symbolName: String {
        switch self {
        case .spotlight:
            return "sparkles"
        case .shortcuts:
            return "bolt.horizontal.circle"
        case .queuePeek:
            return "text.line.first.and.arrowtriangle.forward"
        case .librarySnapshot:
            return "music.note.list"
        case .appStatus:
            return "info.circle"
        }
    }

    static let defaultOrder: [HomeSectionKind] = [
        .spotlight,
        .shortcuts,
        .queuePeek,
        .librarySnapshot,
        .appStatus
    ]
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case midnight
    case paper
    case ember

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight:
            return "Midnight"
        case .paper:
            return "Paper"
        case .ember:
            return "Ember"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .midnight, .ember:
            return .dark
        case .paper:
            return .light
        }
    }

    var backgroundGradient: [Color] {
        switch self {
        case .midnight:
            return [Color(red: 0.06, green: 0.07, blue: 0.10), Color(red: 0.16, green: 0.11, blue: 0.22), Color(red: 0.08, green: 0.12, blue: 0.16)]
        case .paper:
            return [Color(red: 0.98, green: 0.96, blue: 0.93), Color(red: 0.91, green: 0.89, blue: 0.84), Color(red: 0.84, green: 0.86, blue: 0.90)]
        case .ember:
            return [Color(red: 0.13, green: 0.05, blue: 0.05), Color(red: 0.33, green: 0.10, blue: 0.08), Color(red: 0.18, green: 0.09, blue: 0.06)]
        }
    }

    var accent: Color {
        switch self {
        case .midnight:
            return Color(red: 0.86, green: 0.56, blue: 0.92)
        case .paper:
            return Color(red: 0.14, green: 0.18, blue: 0.26)
        case .ember:
            return Color(red: 0.96, green: 0.57, blue: 0.36)
        }
    }
}
