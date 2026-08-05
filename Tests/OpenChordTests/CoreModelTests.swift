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
    }
}
