import Foundation
import Testing
@testable import OpenChord

struct CoreModelTests {
    @Test
    func mediaItemRefRoundTripsThroughJSON() throws {
        let item = MediaItemRef(
            id: "song-1",
            kind: .song,
            title: "Example",
            subtitle: "Artist",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            source: .catalog
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MediaItemRef.self, from: data)

        #expect(decoded == item)
    }

    @Test
    func homeSectionLayoutRoundTrips() throws {
        let layouts: [HomeSectionLayout] = [.carousel(rows: 2), .grid(columns: 4), .list]

        for layout in layouts {
            let data = try JSONEncoder().encode(layout)
            let decoded = try JSONDecoder().decode(HomeSectionLayout.self, from: data)
            #expect(decoded == layout)
        }
    }

    @Test
    func settingsStorePreservesLegacyPayload() throws {
        let defaults = UserDefaults(suiteName: "OpenChordTests-\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let payload = Data("legacy-settings".utf8)

        store.writeLegacyPayload(payload)

        #expect(store.readLegacyPayload() == payload)
    }

    @Test
    func appErrorsProvideRecoveryGuidance() {
        let error = AppError.unsupportedAction(action: "playlist reordering")

        #expect(error.errorDescription?.contains("playlist reordering") == true)
        #expect(error.recoverySuggestion?.contains("Music app") == true)
        #expect(error.userFacingMessage.contains("Music app"))
    }

    @Test @MainActor
    func previewEnvironmentSupportsSearchAndPlayback() async throws {
        let environment = AppEnvironment.preview()
        let query = MusicSearchQuery(term: "Preview", scope: .catalog, kinds: [.song])
        let results = try await environment.catalog.search(query)

        #expect(results.count == 1)
        try await environment.playback.play(results[0])
        #expect(environment.playback.state.status == .playing)
        #expect(environment.playback.state.currentItem == results[0])

        await environment.playback.setShuffle(enabled: true)
        await environment.playback.setRepeatMode(.one)
        #expect(environment.playback.state.shuffleEnabled)
        #expect(environment.playback.state.repeatMode == .one)
    }

    @Test @MainActor
    func previewEnvironmentSupportsHomeSectionsAndDetails() async throws {
        let environment = AppEnvironment.preview()

        let topAlbums = try await environment.catalog.items(for: "topAlbums", limit: 4)
        #expect(topAlbums.count == 1)
        #expect(topAlbums.first?.kind == .album)

        let libraryAlbums = try await environment.library.items(kind: .album, limit: 4, downloadedOnly: false)
        #expect(libraryAlbums.count == 1)
        let tracks = try await environment.details.tracks(for: libraryAlbums[0])
        #expect(tracks.count == 3)
        #expect(tracks.allSatisfy { $0.kind == .song })

        let libraryArtists = try await environment.library.items(kind: .artist, limit: 4, downloadedOnly: false)
        let artistContent = try await environment.details.artistContent(for: libraryArtists[0])
        #expect(artistContent.albums.count == 1)
        #expect(artistContent.topSongs.count == 1)
    }
}
