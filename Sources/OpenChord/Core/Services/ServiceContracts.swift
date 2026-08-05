import Foundation

@MainActor
protocol AuthorizationService {
    var state: AuthorizationState { get }
    func refresh() async
    func requestAuthorization() async
}

struct AuthorizationState: Codable, Equatable, Sendable {
    var isAuthorized = false
    var hasSubscription: Bool?
    var hasCloudLibrary: Bool?
    var lastDiagnosticMessage: String?
}

@MainActor
protocol CatalogService {
    func search(_ query: MusicSearchQuery) async throws -> [MediaItemRef]
    func items(for sectionID: String, limit: Int) async throws -> [MediaItemRef]
}

@MainActor
protocol LibraryService {
    func search(_ query: MusicSearchQuery) async throws -> [MediaItemRef]
    func items(kind: MediaKind, limit: Int, downloadedOnly: Bool) async throws -> [MediaItemRef]
}

@MainActor
protocol PlaybackService {
    var state: PlaybackState { get }
    func refresh() async
    func play(_ item: MediaItemRef) async throws
    func playNext(_ item: MediaItemRef) async throws
    func addToQueue(_ item: MediaItemRef) async throws
    func togglePlayback() async throws
    func skipNext() async throws
    func skipPrevious() async throws
    func setShuffle(enabled: Bool) async
    func setRepeatMode(_ mode: RepeatMode) async
}

@MainActor
final class AppEnvironment {
    let authorization: any AuthorizationService
    let catalog: any CatalogService
    let library: any LibraryService
    let playback: any PlaybackService

    init(
        authorization: any AuthorizationService,
        catalog: any CatalogService,
        library: any LibraryService,
        playback: any PlaybackService
    ) {
        self.authorization = authorization
        self.catalog = catalog
        self.library = library
        self.playback = playback
    }

    static func preview() -> AppEnvironment {
        AppEnvironment(
            authorization: MockAuthorizationService(),
            catalog: MockCatalogService(),
            library: MockLibraryService(),
            playback: MockPlaybackService()
        )
    }

    static func live() -> AppEnvironment {
        AppEnvironment(
            authorization: MusicKitAuthorizationService(),
            catalog: MusicKitCatalogService(),
            library: MusicKitLibraryService(),
            playback: MusicKitPlaybackService()
        )
    }
}
