import SwiftUI
@preconcurrency import MusicKit

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    ForEach(model.homeSections) { section in
                        homeSectionCard(section)
                    }
                }
            }
            .padding(24)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenChord")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("A clean-room Apple Music companion with original visuals, configurable home modules, search, and queue controls.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                statusBadge
            }

            HStack(spacing: 12) {
                quickAction("Authorize", systemImage: "person.badge.key.fill") {
                    Task { await model.requestAuthorization() }
                }
                quickAction("Search", systemImage: "magnifyingglass") {
                    model.selectedSection = .search
                }
                quickAction("Queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
                    model.selectedSection = .queue
                }
                quickAction("Refresh", systemImage: "arrow.clockwise") {
                    Task { await model.refreshAll() }
                }
            }
        }
        .padding(24)
        .background(cardBackground(accent: model.theme.accent.opacity(0.24)))
    }

    private var statusBadge: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(model.authorizationStatus.description.capitalized)
                .font(.headline)
            Text(model.queueSnapshot.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(cardBackground(accent: model.theme.accent.opacity(0.18)))
    }

    private func quickAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.theme.accent)
    }

    @ViewBuilder
    private func homeSectionCard(_ section: HomeSectionKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label(section.title, systemImage: section.symbolName)
                    .font(.headline)
                Spacer()
            }
            Text(section.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            switch section {
            case .spotlight:
                spotlightContent
            case .shortcuts:
                shortcutsContent
            case .queuePeek:
                queuePeekContent
            case .librarySnapshot:
                librarySnapshotContent
            case .appStatus:
                appStatusContent
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(accent: model.theme.accent.opacity(0.16)))
    }

    private var spotlightContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search the catalog and your library from one place.")
            TextField("Try a song, album, artist, or playlist", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Catalog Search") { Task { await model.performCatalogSearch() } }
                Button("Library Search") { model.librarySearchText = model.searchText; Task { await model.performLibrarySearch() } }
            }
        }
    }

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick jumps")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                ForEach(["New Releases", "Top Playlists", "Recently Added", "Album Search"], id: \.self) { preset in
                    presetChip(preset)
                }
            }

            if !model.recentSearches.isEmpty {
                Text("Recent searches")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    ForEach(Array(model.recentSearches.prefix(6)), id: \.self) { term in
                        presetChip(term, systemImage: "clock.arrow.circlepath")
                    }
                }
            }
        }
    }

    private func presetChip(_ title: String, systemImage: String = "sparkles") -> some View {
        Button {
            model.searchText = title
            Task { await model.performCatalogSearch() }
        } label: {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
    }

    private var queuePeekContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.queueSnapshot.currentTitle)
                .font(.headline)
            Text(model.queueSnapshot.currentArtist)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    Task { await model.skipPrevious() }
                } label: {
                    Label("Prev", systemImage: "backward.fill")
                }
                Button {
                    Task { await model.playPause() }
                } label: {
                    Label("Play/Pause", systemImage: "playpause.fill")
                }
                Button {
                    Task { await model.skipNext() }
                } label: {
                    Label("Next", systemImage: "forward.fill")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var librarySnapshotContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            statRow("Catalog songs", model.catalogResults.songs.count)
            statRow("Catalog albums", model.catalogResults.albums.count)
            statRow("Library songs", model.libraryResults.songs.count)
            statRow("Library playlists", model.libraryResults.playlists.count)
        }
    }

    private var appStatusContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            statRow("Theme", model.theme.title)
            statRow("Shuffle", model.queueShuffleEnabled ? "On" : "Off")
            statRow("Repeat", model.queueRepeatMode == .none ? "Off" : model.queueRepeatMode == .all ? "All" : "One")
        }
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        statRow(label, String(value))
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

struct SearchView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                searchHeader
                resultSections(for: model.catalogResults, title: "Apple Music", sourceTint: .pink)
                resultSections(for: model.libraryResults, title: "Library", sourceTint: .blue)
            }
            .padding(24)
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Search Apple Music and your library using the same field, then launch songs, albums, or playlists directly into the app queue.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("Search for music", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await model.performCatalogSearch() }
                    }
                Button("Search Catalog") {
                    Task { await model.performCatalogSearch() }
                }
                Button("Search Library") {
                    model.librarySearchText = model.searchText
                    Task { await model.performLibrarySearch() }
                }
            }

            if !model.recentSearches.isEmpty {
                HStack {
                    Text("Recent searches")
                        .font(.headline)
                    Spacer()
                    Button("Clear") { model.clearRecentSearches() }
                        .buttonStyle(.bordered)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    ForEach(model.recentSearches, id: \.self) { term in
                        Button {
                            model.searchText = term
                        } label: {
                            Label(term, systemImage: "clock")
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if let message = model.lastErrorMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.16)))
    }

    private func resultSections(for results: SearchResults, title: String, sourceTint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                Text("\(results.totalCount)")
                    .foregroundStyle(.secondary)
            }

            if results.isEmpty {
                Text("No results yet. Try a search like \"new releases\" or an artist name.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                SearchResultSection(title: "Songs", items: results.songs, tint: sourceTint)
                SearchResultSection(title: "Albums", items: results.albums, tint: sourceTint)
                SearchResultSection(title: "Playlists", items: results.playlists, tint: sourceTint)
                SearchResultSection(title: "Artists", items: results.artists, tint: sourceTint)
            }
        }
        .padding(18)
        .background(cardBackground(accent: sourceTint.opacity(0.12)))
    }
}

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    libraryBrowse
                    header
                    resultSections
                }
                .padding(24)
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.loadLibraryBrowse() }
                    } label: {
                        Label("Refresh Library", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task {
                if model.libraryBrowse.totalCount == 0 && !model.libraryBrowse.isLoading {
                    await model.loadLibraryBrowse()
                }
            }
            .navigationDestination(for: SearchHit.self) { item in
                LibraryDetailView(item: item)
            }
        }
    }

    private var libraryBrowse: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Browse Library")
                        .font(.title2.bold())
                    Text("Your saved music, ready to play.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Downloaded only", isOn: Binding(
                    get: { model.libraryBrowseDownloadedOnly },
                    set: { model.setLibraryBrowseDownloadedOnly($0) }
                ))
                .toggleStyle(.checkbox)
            }

            if model.libraryBrowse.isLoading {
                ProgressView("Loading library…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if model.libraryBrowse.totalCount == 0 {
                ContentUnavailableView(
                    "No Library Items",
                    systemImage: "music.note.list",
                    description: Text("Authorize Apple Music and add some music to your library, then refresh.")
                )
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                LibraryBrowseRow(title: "Songs", items: model.libraryBrowse.songs, tint: .pink)
                LibraryBrowseRow(title: "Albums", items: model.libraryBrowse.albums, tint: .purple)
                LibraryBrowseRow(title: "Playlists", items: model.libraryBrowse.playlists, tint: .blue)
                LibraryBrowseRow(title: "Artists", items: model.libraryBrowse.artists, tint: .orange)
            }
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.16)))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Library")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Search the user's library independently when you want a narrower, personal view of songs, albums, playlists, and artists.")
                .foregroundStyle(.secondary)
            HStack {
                TextField("Search your library", text: $model.librarySearchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await model.performLibrarySearch() }
                    }
                Button("Search Library") {
                    Task { await model.performLibrarySearch() }
                }
            }
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.16)))
    }

    private var resultSections: some View {
        VStack(alignment: .leading, spacing: 14) {
            SearchResultSection(title: "Songs", items: model.libraryResults.songs, tint: .blue)
            SearchResultSection(title: "Albums", items: model.libraryResults.albums, tint: .blue)
            SearchResultSection(title: "Playlists", items: model.libraryResults.playlists, tint: .blue)
            SearchResultSection(title: "Artists", items: model.libraryResults.artists, tint: .blue)
        }
        .padding(18)
        .background(cardBackground(accent: Color.blue.opacity(0.12)))
    }
}

struct LibraryBrowseRow: View {
    @EnvironmentObject private var model: AppModel

    let title: String
    let items: [SearchHit]
    let tint: Color

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items) { item in
                            browseItem(item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func browseItem(_ item: SearchHit) -> some View {
        switch item {
        case .song:
            Button {
                Task { await model.play(item) }
            } label: {
                LibraryBrowseCard(item: item, tint: tint)
            }
            .buttonStyle(.plain)
        case .album, .playlist, .artist:
            NavigationLink(value: item) {
                LibraryBrowseCard(item: item, tint: tint)
            }
            .buttonStyle(.plain)
        }
    }
}

struct LibraryBrowseCard: View {
    let item: SearchHit
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArtworkThumbnail(url: item.artworkURL, size: 132, symbolName: item.symbolName)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: item.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(tint.opacity(0.85), in: Circle())
                        .padding(7)
                }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 132, alignment: .leading)
    }
}

struct LibraryDetailView: View {
    let item: SearchHit

    @ViewBuilder
    var body: some View {
        switch item {
        case .song(let song, let source):
            SongDetailView(song: song, source: source.mediaSource)
        case .album(let album, let source):
            AlbumDetailView(album: album, source: source.mediaSource)
        case .playlist(let playlist, let source):
            PlaylistDetailView(playlist: playlist, source: source.mediaSource)
        case .artist(let artist, let source):
            ArtistDetailView(artist: artist, source: source.mediaSource)
        }
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject private var model: AppModel

    let album: Album
    let source: MediaSource
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(
                    title: album.title,
                    subtitle: album.artistName,
                    artworkURL: album.artwork?.url(width: 240, height: 240),
                    symbolName: "square.stack"
                )
                trackContent
            }
            .padding(24)
        }
        .navigationTitle(album.title)
        .task { await loadTracks() }
    }

    @ViewBuilder
    private var trackContent: some View {
        if isLoading {
            ProgressView("Loading tracks…")
                .frame(maxWidth: .infinity, minHeight: 140)
        } else if let errorMessage {
            ContentUnavailableView(
                "Unable to Load Album",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if tracks.isEmpty {
            ContentUnavailableView(
                "No Tracks",
                systemImage: "music.note",
                description: Text("Apple Music did not return tracks for this album.")
            )
        } else {
            TrackActionList(tracks: tracks, source: source)
        }
    }

    private func loadTracks() async {
        guard tracks.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let detailedAlbum = try await album.with(.tracks)
            tracks = Array(detailedAlbum.tracks ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var model: AppModel

    let playlist: Playlist
    let source: MediaSource
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(
                    title: playlist.name,
                    subtitle: playlist.curatorName ?? "Playlist",
                    artworkURL: playlist.artwork?.url(width: 240, height: 240),
                    symbolName: "music.note.list"
                )
                trackContent
            }
            .padding(24)
        }
        .navigationTitle(playlist.name)
        .task { await loadTracks() }
    }

    @ViewBuilder
    private var trackContent: some View {
        if isLoading {
            ProgressView("Loading tracks…")
                .frame(maxWidth: .infinity, minHeight: 140)
        } else if let errorMessage {
            ContentUnavailableView(
                "Unable to Load Playlist",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if tracks.isEmpty {
            ContentUnavailableView(
                "No Tracks",
                systemImage: "music.note",
                description: Text("Apple Music did not return tracks for this playlist.")
            )
        } else {
            TrackActionList(tracks: tracks, source: source)
        }
    }

    private func loadTracks() async {
        guard tracks.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let detailedPlaylist = try await playlist.with(.tracks)
            tracks = Array(detailedPlaylist.tracks ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ArtistDetailView: View {
    let artist: Artist
    let source: MediaSource
    @State private var albums: [Album] = []
    @State private var topSongs: [Song] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(
                    title: artist.name,
                    subtitle: artist.genreNames?.joined(separator: ", ") ?? "Artist",
                    artworkURL: artist.artwork?.url(width: 240, height: 240),
                    symbolName: "person.crop.circle"
                )

                if isLoading {
                    ProgressView("Loading artist…")
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Artist",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    if !albums.isEmpty {
                        Text("Albums")
                            .font(.title3.bold())
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                ForEach(albums) { album in
                                    NavigationLink(value: SearchHit.album(album, source: .catalog)) {
                                        LibraryBrowseCard(
                                            item: .album(album, source: .catalog),
                                            tint: .purple
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if !topSongs.isEmpty {
                        Text("Top Songs")
                            .font(.title3.bold())
                            .padding(.top, 4)
                        TrackActionList(tracks: topSongs.map(Track.song), source: source)
                    }

                    if albums.isEmpty && topSongs.isEmpty {
                        ContentUnavailableView(
                            "No Artist Content",
                            systemImage: "person.crop.circle",
                            description: Text("Apple Music did not return albums or top songs for this artist.")
                        )
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(artist.name)
        .task { await loadArtist() }
    }

    private func loadArtist() async {
        guard albums.isEmpty && topSongs.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let detailedArtist = try await artist.with([.albums, .topSongs])
            albums = Array(detailedArtist.albums ?? [])
            topSongs = Array(detailedArtist.topSongs ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SongDetailView: View {
    let song: Song
    let source: MediaSource

    var body: some View {
        TrackActionList(tracks: [.song(song)], source: source)
            .padding(24)
            .navigationTitle(song.title)
    }
}

struct TrackActionList: View {
    let tracks: [Track]
    let source: MediaSource

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                TrackActionRow(index: index + 1, track: track, source: source)
            }
        }
    }
}

struct TrackActionRow: View {
    @EnvironmentObject private var model: AppModel

    let index: Int
    let track: Track
    let source: MediaSource

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
            ArtworkThumbnail(url: track.artwork?.url(width: 80, height: 80), size: 48, symbolName: "music.note")
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button("Play Now", systemImage: "play.fill") {
                    Task { await model.play(track, source: source) }
                }
                Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                    Task { await model.playNext(track, source: source) }
                }
                Button("Add to Queue", systemImage: "text.badge.plus") {
                    Task { await model.addToQueue(track, source: source) }
                }
            } label: {
                Label("Track actions", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(10)
        .background(cardBackground(accent: Color.white.opacity(0.06)))
    }
}

@MainActor
@ViewBuilder
private func detailHeader(title: String, subtitle: String, artworkURL: URL?, symbolName: String) -> some View {
    HStack(alignment: .top, spacing: 18) {
        ArtworkThumbnail(url: artworkURL, size: 160, symbolName: symbolName)
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        Spacer()
    }
    .padding(18)
    .background(cardBackground(accent: Color.white.opacity(0.08)))
}

struct PlayerBarView: View {
    @EnvironmentObject private var model: AppModel

    private var isPlaying: Bool {
        model.queueSnapshot.statusText.caseInsensitiveCompare("Playing") == .orderedSame
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(
                url: model.queueSnapshot.currentArtworkURL,
                size: 44,
                symbolName: "music.note"
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(model.queueSnapshot.currentTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(model.queueSnapshot.currentArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button {
                    Task { await model.skipPrevious() }
                } label: {
                    Image(systemName: "backward.fill")
                }
                .help("Previous track")

                Button {
                    Task { await model.playPause() }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                }
                .help(isPlaying ? "Pause" : "Play")

                Button {
                    Task { await model.skipNext() }
                } label: {
                    Image(systemName: "forward.fill")
                }
                .help("Next track")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

struct QueueView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                nowPlayingCard
                queueControls
                queueList
            }
            .padding(24)
        }
    }

    private var nowPlayingCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ArtworkThumbnail(url: model.queueSnapshot.entries.first?.artworkURL, size: 120)
            VStack(alignment: .leading, spacing: 8) {
                Text("Now Playing")
                    .font(.headline)
                Text(model.queueSnapshot.currentTitle)
                    .font(.title2.bold())
                Text(model.queueSnapshot.currentArtist)
                    .foregroundStyle(.secondary)
                Text("Queue status: \(model.queueSnapshot.statusText)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.18)))
    }

    private var queueControls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.skipPrevious() }
            } label: {
                Label("Previous", systemImage: "backward.fill")
            }
            .buttonStyle(.bordered)

            Button {
                Task { await model.playPause() }
            } label: {
                Label("Play / Pause", systemImage: "playpause.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(model.theme.accent)

            Button {
                Task { await model.skipNext() }
            } label: {
                Label("Next", systemImage: "forward.fill")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                Task { await model.toggleShuffle() }
            } label: {
                Label(model.queueShuffleEnabled ? "Shuffle On" : "Shuffle Off", systemImage: "shuffle")
            }
            .buttonStyle(.bordered)

            Button {
                Task { await model.cycleRepeatMode() }
            } label: {
                Label("Repeat: \(model.queueRepeatMode == .none ? "Off" : model.queueRepeatMode == .all ? "All" : "One")", systemImage: "repeat")
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .background(cardBackground(accent: Color.white.opacity(0.08)))
    }

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Queue")
                .font(.title3.bold())

            if model.queueSnapshot.entries.isEmpty {
                Text("Nothing is queued yet. Search for a song or playlist and press play to load the application queue.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(model.queueSnapshot.entries) { entry in
                    HStack(spacing: 14) {
                        ArtworkThumbnail(url: entry.artworkURL, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)
                            Text(entry.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(cardBackground(accent: Color.white.opacity(0.05)))
                }
            }
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.12)))
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                themeSection
                homeSectionConfiguration
                playbackSection
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Tune the home layout, visual theme, and playback defaults.")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.16)))
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
            Picker("Theme", selection: Binding(
                get: { model.theme },
                set: { model.updateTheme($0) }
            )) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .background(cardBackground(accent: Color.white.opacity(0.08)))
    }

    private var homeSectionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Home Sections")
                    .font(.headline)
            }

            Text("Use the arrows to reorder and uncheck sections you do not want on the dashboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(Array(model.homeSections.enumerated()), id: \.element) { index, section in
                    HStack(spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { true },
                            set: { enabled in
                                if !enabled {
                                    model.toggleHomeSection(section)
                                }
                            }
                        )) {
                            Label(section.title, systemImage: section.symbolName)
                        }
                        .toggleStyle(.switch)

                        Spacer()

                        Button {
                            guard index > 0 else { return }
                            model.moveHomeSection(from: IndexSet(integer: index), to: index - 1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(index == 0)

                        Button {
                            guard index < model.homeSections.count - 1 else { return }
                            model.moveHomeSection(from: IndexSet(integer: index), to: index + 2)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(index == model.homeSections.count - 1)
                    }
                    .padding(12)
                    .background(cardBackground(accent: model.theme.accent.opacity(0.08)))
                }
            }
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.12)))
    }

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playback Defaults")
                .font(.headline)

            Toggle("Shuffle application queue", isOn: Binding(
                get: { model.queueShuffleEnabled },
                set: { newValue in
                    model.updateQueueDefaults(shuffle: newValue, repeatMode: model.queueRepeatMode)
                }
            ))

            Picker("Repeat", selection: Binding(
                get: { model.queueRepeatMode },
                set: { newValue in
                    model.updateQueueDefaults(shuffle: model.queueShuffleEnabled, repeatMode: newValue)
                }
            )) {
                Text("Off").tag(MusicPlayer.RepeatMode.none)
                Text("One").tag(MusicPlayer.RepeatMode.one)
                Text("All").tag(MusicPlayer.RepeatMode.all)
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .background(cardBackground(accent: Color.white.opacity(0.08)))
    }
}

struct SearchResultSection: View {
    let title: String
    let items: [SearchHit]
    let tint: Color

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(items) { item in
                        SearchResultCard(item: item, tint: tint)
                    }
                }
            }
        }
    }
}

struct SearchResultCard: View {
    @EnvironmentObject private var model: AppModel
    let item: SearchHit
    let tint: Color

    var body: some View {
        Button {
            Task { await model.play(item) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomLeading) {
                    ArtworkThumbnail(url: item.artworkURL, size: 220)
                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 96)
                        .clipped()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.playableDescription.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(item.source.label)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(12)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(item.source.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
            .contextMenu {
                Button("Play Now") {
                    Task { await model.play(item) }
                }
                if item.isPlayable {
                    Button("Play Next") {
                        Task { await model.playNext(item) }
                    }
                    Button("Add to Queue") {
                        Task { await model.addToQueue(item) }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ArtworkThumbnail: View {
    let url: URL?
    let size: CGFloat
    let symbolName: String

    init(url: URL?, size: CGFloat, symbolName: String = "music.note") {
        self.url = url
        self.size = size
        self.symbolName = symbolName
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackGlyph
                    @unknown default:
                        fallbackGlyph
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                fallbackGlyph
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }

    private var fallbackGlyph: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.28, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

func cardBackground(accent: Color) -> some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
}
