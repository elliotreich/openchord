import Foundation
@preconcurrency import MusicKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published private(set) var authorizationState = AuthorizationState()
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
    @Published var configurableHomeSections: [HomeSection]
    @Published private(set) var homeContent: [UUID: HomeSectionContent]

    private let environment: AppEnvironment
    private let settingsStore = SettingsStore()

    init(environment: AppEnvironment = .live()) {
        self.environment = environment
        let persisted = Self.loadPersistedState(from: settingsStore.readLegacyPayload())
        self.homeSections = persisted?.homeSections ?? HomeSectionKind.defaultOrder
        self.theme = persisted?.theme ?? .midnight
        self.queueShuffleEnabled = persisted?.queueShuffleEnabled ?? false
        self.queueRepeatMode = persisted?.queueRepeatMode.musicKitValue ?? .none
        self.recentSearches = persisted?.recentSearches ?? []
        self.libraryBrowseDownloadedOnly = persisted?.libraryBrowseDownloadedOnly ?? false
        let configurableHomeSections = persisted?.configurableHomeSections ?? HomeSection.v2Defaults
        self.configurableHomeSections = configurableHomeSections
        self.homeContent = Dictionary(uniqueKeysWithValues: configurableHomeSections.map { ($0.id, HomeSectionContent()) })

        Task {
            await refreshAuthorization()
            await refreshPlaybackSnapshot()
            await loadLibraryBrowse()
            await loadHomeContent()
        }
    }

    func refreshAuthorization() async {
        await environment.authorization.refresh()
        authorizationState = environment.authorization.state
        authorizationStatus = MusicAuthorization.currentStatus
        guard authorizationStatus == .notDetermined else { return }
        await environment.authorization.requestAuthorization()
        authorizationState = environment.authorization.state
        authorizationStatus = MusicAuthorization.currentStatus
    }

    func requestAuthorization() async {
        await environment.authorization.requestAuthorization()
        authorizationState = environment.authorization.state
        authorizationStatus = MusicAuthorization.currentStatus
        await loadLibraryBrowse()
        await loadHomeContent()
    }

    func refreshPlaybackSnapshot() async {
        await environment.playback.refresh()
        let state = environment.playback.state
        queueShuffleEnabled = state.shuffleEnabled
        queueRepeatMode = Self.musicKitRepeatMode(for: state.repeatMode)
        queueSnapshot = QueueSnapshot(
            statusText: state.status.rawValue.capitalized,
            currentTitle: state.currentItem?.title ?? "Nothing playing",
            currentArtist: state.currentItem?.subtitle.isEmpty == false
                ? state.currentItem?.subtitle ?? ""
                : (authorizationStatus == .authorized ? "Choose something to play" : "Authorize Apple Music"),
            currentArtworkURL: state.currentItem?.artworkURL,
            currentArtwork: state.currentItem?.artwork,
            entries: state.queue.map { item in
                QueueEntrySnapshot(
                    id: item.id,
                    title: item.title,
                    subtitle: item.subtitle,
                    artworkURL: item.artworkURL,
                    artwork: item.artwork
                )
            }
        )
    }

    private static func musicKitRepeatMode(for mode: RepeatMode) -> MusicPlayer.RepeatMode {
        switch mode {
        case .off:
            .none
        case .one:
            .one
        case .all:
            .all
        }
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
            let query = MusicSearchQuery(
                term: term,
                scope: .catalog,
                kinds: [.song, .album, .playlist, .artist]
            )
            catalogResults = SearchResults(items: try await environment.catalog.search(query))
            recordRecentSearch(term)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
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
            let query = MusicSearchQuery(
                term: term,
                scope: .library,
                kinds: [.song, .album, .playlist, .artist]
            )
            libraryResults = SearchResults(items: try await environment.library.search(query))
            recordRecentSearch(term)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
        }
    }

    func play(_ item: MediaItemRef) async {
        guard item.isPlayable else {
            lastErrorMessage = AppError.unsupportedAction(action: unsupportedPlaybackAction(for: item)).userFacingMessage
            return
        }

        do {
            try await environment.playback.play(item)
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
        }
    }

    func playNext(_ item: MediaItemRef) async {
        await queue(item, position: .afterCurrentEntry)
    }

    func addToQueue(_ item: MediaItemRef) async {
        await queue(item, position: .tail)
    }

    func loadTracks(for item: MediaItemRef) async throws -> [MediaItemRef] {
        try await environment.details.tracks(for: item)
    }

    func loadArtistContent(for item: MediaItemRef) async throws -> ArtistDetail {
        try await environment.details.artistContent(for: item)
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
            try await environment.playback.togglePlayback()
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
        }
    }

    func skipNext() async {
        do {
            try await environment.playback.skipNext()
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
        }
    }

    func skipPrevious() async {
        do {
            try await environment.playback.skipPrevious()
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
        }
    }

    func toggleShuffle() async {
        await environment.playback.setShuffle(enabled: !queueShuffleEnabled)
        await refreshPlaybackSnapshot()
    }

    func cycleRepeatMode() async {
        let nextMode: MusicPlayer.RepeatMode = switch queueRepeatMode {
        case .none: .all
        case .all: .one
        case .one: .none
        @unknown default: .none
        }
        await environment.playback.setRepeatMode(Self.coreRepeatMode(for: nextMode))
        await refreshPlaybackSnapshot()
    }

    private static func coreRepeatMode(for mode: MusicPlayer.RepeatMode) -> RepeatMode {
        switch mode {
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

    func moveHomeSection(_ source: HomeSectionKind, relativeTo destination: HomeSectionKind, placeAfter: Bool) {
        guard source != destination,
              let sourceIndex = homeSections.firstIndex(of: source),
              let destinationIndex = homeSections.firstIndex(of: destination) else {
            return
        }

        let movedSection = homeSections.remove(at: sourceIndex)
        var insertionIndex = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        if placeAfter {
            insertionIndex += 1
        }
        homeSections.insert(movedSection, at: insertionIndex)
        persistSettings()
    }

    func updateTheme(_ newTheme: AppTheme) {
        theme = newTheme
        persistSettings()
    }

    func updateQueueDefaults(shuffle: Bool, repeatMode: MusicPlayer.RepeatMode) {
        queueShuffleEnabled = shuffle
        queueRepeatMode = repeatMode
        Task {
            await environment.playback.setShuffle(enabled: shuffle)
            await environment.playback.setRepeatMode(Self.coreRepeatMode(for: repeatMode))
            await refreshPlaybackSnapshot()
        }
        persistSettings()
    }

    func refreshAll() async {
        await refreshAuthorization()
        await refreshPlaybackSnapshot()
        await performCatalogSearch()
        await performLibrarySearch()
        await loadLibraryBrowse()
        await loadHomeContent()
    }

    func loadHomeContent() async {
        let sections = configurableHomeSections
            .filter(\.isEnabled)
            .sorted { $0.order < $1.order }

        for section in sections {
            await loadHomeSection(section)
        }
    }

    func reloadHomeSection(_ sectionID: UUID) async {
        guard let section = configurableHomeSections.first(where: { $0.id == sectionID }) else { return }
        await loadHomeSection(section)
    }

    func setConfigurableHomeSectionEnabled(_ sectionID: UUID, enabled: Bool) {
        guard let index = configurableHomeSections.firstIndex(where: { $0.id == sectionID }) else { return }
        configurableHomeSections[index].isEnabled = enabled
        persistSettings()
        guard enabled else { return }
        let section = configurableHomeSections[index]
        Task { await loadHomeSection(section) }
    }

    func moveConfigurableHomeSection(from offsets: IndexSet, to destination: Int) {
        configurableHomeSections.move(fromOffsets: offsets, toOffset: destination)
        normalizeConfigurableHomeSectionOrder()
        persistSettings()
    }

    func updateConfigurableHomeSection(_ sectionID: UUID, layout: HomeSectionLayout? = nil, itemLimit: Int? = nil, artworkShape: HomeArtworkShape? = nil) {
        guard let index = configurableHomeSections.firstIndex(where: { $0.id == sectionID }) else { return }
        if let layout {
            configurableHomeSections[index].layout = layout
        }
        if let itemLimit {
            configurableHomeSections[index].itemLimit = max(1, itemLimit)
        }
        if let artworkShape {
            configurableHomeSections[index].artworkShape = artworkShape
        }
        persistSettings()
        let section = configurableHomeSections[index]
        Task { await loadHomeSection(section) }
    }

    func loadLibraryBrowse() async {
        let downloadedOnly = libraryBrowseDownloadedOnly
        libraryBrowse.isLoading = true
        defer { libraryBrowse.isLoading = false }

        do {
            let songs = try await environment.library.items(kind: .song, limit: 10, downloadedOnly: downloadedOnly)
            let albums = try await environment.library.items(kind: .album, limit: 10, downloadedOnly: downloadedOnly)
            let playlists = try await environment.library.items(kind: .playlist, limit: 10, downloadedOnly: downloadedOnly)
            let artists = try await environment.library.items(kind: .artist, limit: 10, downloadedOnly: downloadedOnly)

            libraryBrowse = LibraryBrowseSnapshot(
                songs: songs,
                albums: albums,
                playlists: playlists,
                artists: artists,
                downloadedOnly: downloadedOnly,
                lastUpdated: Date()
            )
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
        }
    }

    private func loadHomeSection(_ section: HomeSection) async {
        homeContent[section.id] = HomeSectionContent(isLoading: true)

        do {
            let items: [MediaItemRef]
            switch section.kindID {
            case "topSongs", "topAlbums", "topPlaylists":
                items = try await environment.catalog.items(for: section.kindID, limit: section.itemLimit)
            case "recentlyPlayed", "recentlyAdded", "playlists", "albums":
                items = try await environment.library.items(for: section.kindID, limit: section.itemLimit, downloadedOnly: false)
            default:
                throw AppError.unsupportedAction(action: "loading home section \(section.kindID)")
            }

            homeContent[section.id] = HomeSectionContent(
                items: items,
                isLoading: false,
                errorMessage: nil,
                lastUpdated: Date()
            )
        } catch {
            homeContent[section.id] = HomeSectionContent(
                isLoading: false,
                errorMessage: AppError.from(error).userFacingMessage,
                lastUpdated: Date()
            )
        }
    }

    private func normalizeConfigurableHomeSectionOrder() {
        for index in configurableHomeSections.indices {
            configurableHomeSections[index].order = index
        }
    }

    private func queue(_ item: MediaItemRef, position: MusicPlayer.Queue.EntryInsertionPosition) async {
        guard item.isPlayable else {
            lastErrorMessage = AppError.unsupportedAction(action: unsupportedPlaybackAction(for: item)).userFacingMessage
            return
        }

        do {
            switch position {
            case .afterCurrentEntry:
                try await environment.playback.playNext(item)
            case .tail:
                try await environment.playback.addToQueue(item)
            @unknown default:
                return
            }
            await refreshPlaybackSnapshot()
        } catch {
            lastErrorMessage = AppError.from(error).userFacingMessage
        }
    }

    private func unsupportedPlaybackAction(for item: MediaItemRef) -> String {
        switch item.kind {
        case .artist:
            "playing an artist"
        case .musicVideo:
            "playing a music video"
        default:
            "playing this item"
        }
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
            libraryBrowseDownloadedOnly: libraryBrowseDownloadedOnly,
            configurableHomeSections: configurableHomeSections
        )

        do {
            let data = try JSONEncoder().encode(state)
            settingsStore.writeLegacyPayload(data)
        } catch {
            lastErrorMessage = AppError.unknown(message: error.localizedDescription).userFacingMessage
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
    var configurableHomeSections: [HomeSection]?

    init(homeSections: [HomeSectionKind], theme: AppTheme, queueShuffleEnabled: Bool, queueRepeatMode: MusicPlayer.RepeatMode, recentSearches: [String], libraryBrowseDownloadedOnly: Bool, configurableHomeSections: [HomeSection]) {
        self.homeSections = homeSections
        self.theme = theme
        self.queueShuffleEnabled = queueShuffleEnabled
        self.queueRepeatMode = QueueRepeatModeCodable(queueRepeatMode)
        self.recentSearches = recentSearches
        self.libraryBrowseDownloadedOnly = libraryBrowseDownloadedOnly
        self.configurableHomeSections = configurableHomeSections
    }

    enum CodingKeys: String, CodingKey {
        case homeSections
        case theme
        case queueShuffleEnabled
        case queueRepeatMode
        case recentSearches
        case libraryBrowseDownloadedOnly
        case configurableHomeSections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeSections = try container.decode([HomeSectionKind].self, forKey: .homeSections)
        theme = try container.decode(AppTheme.self, forKey: .theme)
        queueShuffleEnabled = try container.decode(Bool.self, forKey: .queueShuffleEnabled)
        queueRepeatMode = try container.decode(QueueRepeatModeCodable.self, forKey: .queueRepeatMode)
        recentSearches = try container.decodeIfPresent([String].self, forKey: .recentSearches) ?? []
        libraryBrowseDownloadedOnly = try container.decodeIfPresent(Bool.self, forKey: .libraryBrowseDownloadedOnly) ?? false
        configurableHomeSections = try container.decodeIfPresent([HomeSection].self, forKey: .configurableHomeSections)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(homeSections, forKey: .homeSections)
        try container.encode(theme, forKey: .theme)
        try container.encode(queueShuffleEnabled, forKey: .queueShuffleEnabled)
        try container.encode(queueRepeatMode, forKey: .queueRepeatMode)
        try container.encode(recentSearches, forKey: .recentSearches)
        try container.encode(libraryBrowseDownloadedOnly, forKey: .libraryBrowseDownloadedOnly)
        try container.encodeIfPresent(configurableHomeSections, forKey: .configurableHomeSections)
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
    var songs: [MediaItemRef] = []
    var albums: [MediaItemRef] = []
    var playlists: [MediaItemRef] = []
    var artists: [MediaItemRef] = []

    init(items: [MediaItemRef] = []) {
        songs = items.filter { $0.kind == .song }
        albums = items.filter { $0.kind == .album }
        playlists = items.filter { $0.kind == .playlist }
        artists = items.filter { $0.kind == .artist }
    }

    var isEmpty: Bool {
        songs.isEmpty && albums.isEmpty && playlists.isEmpty && artists.isEmpty
    }

    var totalCount: Int {
        songs.count + albums.count + playlists.count + artists.count
    }
}

struct QueueSnapshot {
    var statusText = "Stopped"
    var currentTitle = "Nothing playing"
    var currentArtist = "Authorize Apple Music"
    var currentArtworkURL: URL? = nil
    var currentArtwork: Artwork? = nil
    var entries: [QueueEntrySnapshot] = []
}

struct LibraryBrowseSnapshot {
    var songs: [MediaItemRef] = []
    var albums: [MediaItemRef] = []
    var playlists: [MediaItemRef] = []
    var artists: [MediaItemRef] = []
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
    let artwork: Artwork?
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
