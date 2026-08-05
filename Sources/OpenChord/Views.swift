import SwiftUI
import AppKit
@preconcurrency import MusicKit

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    configurableHomeContent

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                        ForEach(model.homeSections) { section in
                            homeSectionCard(section)
                        }
                    }
                }
                .padding(24)
            }
            .navigationDestination(for: MediaItemRef.self) { item in
                LibraryDetailView(item: item)
            }
        }
    }

    private var heroCard: some View {
        HStack(alignment: .top, spacing: 20) {
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

            if model.authorizationStatus != .authorized {
                Button {
                    Task { await model.requestAuthorization() }
                } label: {
                    Label("Authorize Apple Music", systemImage: "person.badge.key.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(model.theme.accent)
            }
        }
        .padding(24)
        .background(cardBackground(accent: model.theme.accent.opacity(0.24)))
    }

    private var statusBadge: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(authorizationStatusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(connectionSummary)
                    .font(.subheadline.weight(.semibold))
                Text(playbackSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.white.opacity(0.07), in: Capsule())
    }

    private var authorizationTitle: String {
        switch model.authorizationStatus {
        case .authorized:
            "Authorized"
        case .denied:
            "Access Denied"
        case .restricted:
            "Restricted"
        case .notDetermined:
            "Needs Authorization"
        @unknown default:
            "Unknown"
        }
    }

    private var connectionSummary: String {
        model.authorizationStatus == .authorized ? "Apple Music ready" : authorizationTitle
    }

    private var playbackSummary: String {
        switch model.queueSnapshot.statusText.lowercased() {
        case "playing":
            "Playing now"
        case "paused":
            "Paused"
        default:
            "Nothing playing"
        }
    }

    private var authorizationStatusColor: Color {
        model.authorizationStatus == .authorized ? .green : .orange
    }

    @ViewBuilder
    private var configurableHomeContent: some View {
        let enabledSections = model.configurableHomeSections
            .filter { $0.isEnabled }
            .sorted { $0.order < $1.order }

        if !enabledSections.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Music")
                            .font(.title2.bold())
                        Text("Personal library sections and Apple Music charts, loaded independently.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await model.loadHomeContent() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh Home")
                }

                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(enabledSections) { section in
                        ConfigurableHomeSectionView(
                            section: section,
                            content: model.homeContent[section.id] ?? HomeSectionContent()
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func homeSectionCard(_ section: HomeSectionKind) -> some View {
        DashboardSectionCard(
            section: section,
            accent: model.theme.accent,
            onMove: { source, destination, placeAfter in
                model.moveHomeSection(source, relativeTo: destination, placeAfter: placeAfter)
            }
        ) {
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
                    ForEach(Array(model.recentSearches.prefix(4)), id: \.self) { term in
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

struct DashboardSectionCard<Content: View>: View {
    let section: HomeSectionKind
    let accent: Color
    let onMove: (HomeSectionKind, HomeSectionKind, Bool) -> Void
    let content: Content

    @State private var isDropTargeted = false

    init(
        section: HomeSectionKind,
        accent: Color,
        onMove: @escaping (HomeSectionKind, HomeSectionKind, Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.accent = accent
        self.onMove = onMove
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Label(section.title, systemImage: section.symbolName)
                    .font(.headline)
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .help("Drag to reorder \(section.title)")
            }
            .contentShape(Rectangle())
            .draggable(section.rawValue)

            Text(section.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .background(cardBackground(accent: accent.opacity(0.16)))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isDropTargeted ? accent : .clear,
                    style: StrokeStyle(lineWidth: 2, dash: isDropTargeted ? [7, 5] : [])
                )
                .animation(.easeOut(duration: 0.16), value: isDropTargeted)
        }
        .dropDestination(for: String.self) { droppedItems, location in
            guard let rawValue = droppedItems.first,
                  let source = HomeSectionKind(rawValue: rawValue),
                  source != section else {
                return false
            }

            onMove(source, section, location.y > 140)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
}

struct ConfigurableHomeSectionView: View {
    @EnvironmentObject private var model: AppModel

    let section: HomeSection
    let content: HomeSectionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(.title3.bold())
                Spacer()
                Button {
                    Task { await model.reloadHomeSection(section.id) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh \(section.title)")
            }

            if content.isLoading {
                ProgressView("Loading \(section.title)…")
                    .frame(maxWidth: .infinity, minHeight: 96)
            } else if let errorMessage = content.errorMessage {
                HStack(spacing: 10) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") {
                        Task { await model.reloadHomeSection(section.id) }
                    }
                    .buttonStyle(.bordered)
                }
            } else if content.items.isEmpty {
                Text("Nothing is available for this section yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            } else {
                sectionItems
            }
        }
        .padding(18)
        .background(cardBackground(accent: model.theme.accent.opacity(0.14)))
    }

    @ViewBuilder
    private var sectionItems: some View {
        switch section.layout {
        case .carousel(let rows):
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: Array(repeating: GridItem(.fixed(202), spacing: 12), count: max(1, min(rows, 2))),
                    spacing: 14
                ) {
                    ForEach(content.items) { item in
                        homeItem(item)
                    }
                }
                .frame(height: CGFloat(max(1, min(rows, 2))) * 202)
            }
        case .grid(let columns):
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 120), spacing: 12), count: max(1, min(columns, 5))),
                spacing: 14
            ) {
                ForEach(content.items) { item in
                    homeItem(item)
                }
            }
        case .list:
            MediaItemActionList(items: content.items)
        }
    }

    @ViewBuilder
    private func homeItem(_ item: MediaItemRef) -> some View {
        if item.kind == .song {
            Button {
                Task { await model.play(item) }
            } label: {
                ConfigurableHomeItemCard(item: item, artworkShape: section.artworkShape)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: item) {
                ConfigurableHomeItemCard(item: item, artworkShape: section.artworkShape)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ConfigurableHomeItemCard: View {
    let item: MediaItemRef
    let artworkShape: HomeArtworkShape

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArtworkThumbnail(
                url: item.artworkURL,
                artwork: item.artwork,
                size: 144,
                symbolName: item.symbolName,
                shape: artworkShape
            )
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(item.subtitle.isEmpty ? item.playableDescription : item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 144, alignment: .leading)
    }
}

struct SearchView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchHeader
                    resultSections(for: model.catalogResults, title: "Apple Music", sourceTint: .pink)
                    resultSections(for: model.libraryResults, title: "Library", sourceTint: .blue)
                }
                .padding(24)
            }
            .navigationDestination(for: MediaItemRef.self) { item in
                LibraryDetailView(item: item)
            }
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
            .navigationDestination(for: MediaItemRef.self) { item in
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
    let items: [MediaItemRef]
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
    private func browseItem(_ item: MediaItemRef) -> some View {
        if item.kind == .song {
            Button {
                Task { await model.play(item) }
            } label: {
                LibraryBrowseCard(item: item, tint: tint)
            }
            .buttonStyle(.plain)
        } else if item.kind == .album || item.kind == .playlist || item.kind == .artist {
            NavigationLink(value: item) {
                LibraryBrowseCard(item: item, tint: tint)
            }
            .buttonStyle(.plain)
        } else {
            EmptyView()
        }
    }
}

struct LibraryBrowseCard: View {
    let item: MediaItemRef
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArtworkThumbnail(url: item.artworkURL, artwork: item.artwork, size: 132, symbolName: item.symbolName)
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
    let item: MediaItemRef

    @ViewBuilder
    var body: some View {
        switch item.kind {
        case .song:
            MediaItemActionList(items: [item])
                .padding(24)
                .navigationTitle(item.title)
        case .album:
            AlbumDetailView(item: item)
        case .playlist:
            PlaylistDetailView(item: item)
        case .artist:
            ArtistDetailView(item: item)
        case .musicVideo:
            ContentUnavailableView(
                "Unsupported Item",
                systemImage: item.symbolName,
                description: Text("Music videos are not part of the library browser yet.")
            )
        }
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject private var model: AppModel

    let item: MediaItemRef
    @State private var tracks: [MediaItemRef] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(
                    title: item.title,
                    subtitle: item.subtitle,
                    artworkURL: item.artworkURL,
                    artwork: item.artwork,
                    symbolName: item.symbolName
                )
                trackContent
            }
            .padding(24)
        }
        .navigationTitle(item.title)
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
            MediaItemActionList(items: tracks)
        }
    }

    private func loadTracks() async {
        guard tracks.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            tracks = try await model.loadTracks(for: item)
        } catch {
            errorMessage = AppError.from(error).userFacingMessage
        }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var model: AppModel

    let item: MediaItemRef
    @State private var tracks: [MediaItemRef] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(
                    title: item.title,
                    subtitle: item.subtitle,
                    artworkURL: item.artworkURL,
                    artwork: item.artwork,
                    symbolName: item.symbolName
                )
                trackContent
            }
            .padding(24)
        }
        .navigationTitle(item.title)
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
            MediaItemActionList(items: tracks)
        }
    }

    private func loadTracks() async {
        guard tracks.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            tracks = try await model.loadTracks(for: item)
        } catch {
            errorMessage = AppError.from(error).userFacingMessage
        }
    }
}

struct ArtistDetailView: View {
    @EnvironmentObject private var model: AppModel

    let item: MediaItemRef
    @State private var albums: [MediaItemRef] = []
    @State private var topSongs: [MediaItemRef] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(
                    title: item.title,
                    subtitle: item.subtitle,
                    artworkURL: item.artworkURL,
                    artwork: item.artwork,
                    symbolName: item.symbolName
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
                                    NavigationLink(value: album) {
                                        LibraryBrowseCard(item: album, tint: .purple)
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
                        MediaItemActionList(items: topSongs)
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
        .navigationTitle(item.title)
        .task { await loadArtist() }
    }

    private func loadArtist() async {
        guard albums.isEmpty && topSongs.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let content = try await model.loadArtistContent(for: item)
            albums = content.albums
            topSongs = content.topSongs
        } catch {
            errorMessage = AppError.from(error).userFacingMessage
        }
    }
}

struct MediaItemActionList: View {
    @EnvironmentObject private var model: AppModel

    let items: [MediaItemRef]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                MediaItemActionRow(index: index + 1, item: item)
            }
        }
    }
}

struct MediaItemActionRow: View {
    @EnvironmentObject private var model: AppModel

    let index: Int
    let item: MediaItemRef

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
            ArtworkThumbnail(url: item.artworkURL, artwork: item.artwork, size: 48, symbolName: item.symbolName)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button("Play Now", systemImage: "play.fill") {
                    Task { await model.play(item) }
                }
                if item.isPlayable {
                    Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                        Task { await model.playNext(item) }
                    }
                    Button("Add to Queue", systemImage: "text.badge.plus") {
                        Task { await model.addToQueue(item) }
                    }
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
private func detailHeader(title: String, subtitle: String, artworkURL: URL?, artwork: Artwork?, symbolName: String) -> some View {
    HStack(alignment: .top, spacing: 18) {
        ArtworkThumbnail(url: artworkURL, artwork: artwork, size: 160, symbolName: symbolName)
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
                artwork: model.queueSnapshot.currentArtwork,
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
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Button {
                    Task { await model.playPause() }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                }
                .help(isPlaying ? "Pause" : "Play")
                .keyboardShortcut(.space, modifiers: [])

                Button {
                    Task { await model.skipNext() }
                } label: {
                    Image(systemName: "forward.fill")
                }
                .help("Next track")
                .keyboardShortcut(.rightArrow, modifiers: [.command])
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
            ArtworkThumbnail(url: model.queueSnapshot.currentArtworkURL, artwork: model.queueSnapshot.currentArtwork, size: 120)
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
                        ArtworkThumbnail(url: entry.artworkURL, artwork: entry.artwork, size: 56)
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
                musicAccessSection
                themeSection
                homeSectionConfiguration
                configurableHomeSectionConfiguration
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

    private var musicAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Music Access")
                    .font(.headline)
                Spacer()
                Text(model.authorizationStatus.description.capitalized)
                    .foregroundStyle(.secondary)
            }

            accessRow("Catalog playback", value: accessValue(model.authorizationState.hasSubscription))
            accessRow("Cloud Library", value: accessValue(model.authorizationState.hasCloudLibrary))

            HStack {
                Button("Request Access") {
                    Task { await model.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh Diagnostics") {
                    Task { await model.refreshAuthorization() }
                }
                .buttonStyle(.bordered)
            }

            if let diagnostic = model.authorizationState.lastDiagnosticMessage {
                Text(diagnostic)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
        .background(cardBackground(accent: Color.pink.opacity(0.12)))
    }

    private func accessRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func accessValue(_ value: Bool?) -> String {
        switch value {
        case .some(true):
            "Available"
        case .some(false):
            "Unavailable"
        case nil:
            "Not checked"
        }
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

            Text("Drag a card by its handle on Home, or use the arrows here. Uncheck sections you do not want on the dashboard.")
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

    private var configurableHomeSectionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Music Home Sections")
                .font(.headline)

            Text("Choose which library and Apple Music sections appear on Home, then tune their order, layout, item count, and artwork shape.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(Array(model.configurableHomeSections.enumerated()), id: \.element.id) { index, section in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { section.isEnabled },
                                set: { enabled in
                                    model.setConfigurableHomeSectionEnabled(section.id, enabled: enabled)
                                }
                            )) {
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .toggleStyle(.switch)

                            Spacer()

                            Button {
                                guard index > 0 else { return }
                                model.moveConfigurableHomeSection(from: IndexSet(integer: index), to: index - 1)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .disabled(index == 0)

                            Button {
                                guard index < model.configurableHomeSections.count - 1 else { return }
                                model.moveConfigurableHomeSection(from: IndexSet(integer: index), to: index + 2)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .disabled(index == model.configurableHomeSections.count - 1)
                        }

                        HStack(spacing: 16) {
                            Picker("Layout", selection: Binding(
                                get: { section.layout.choice },
                                set: { choice in
                                    let layout: HomeSectionLayout = switch choice {
                                    case .carousel:
                                        .carousel(rows: 1)
                                    case .grid:
                                        .grid(columns: 4)
                                    case .list:
                                        .list
                                    }
                                    model.updateConfigurableHomeSection(section.id, layout: layout)
                                }
                            )) {
                                ForEach(HomeSectionLayoutChoice.allCases) { choice in
                                    Text(choice.title).tag(choice)
                                }
                            }
                            .frame(width: 180)

                            Stepper(
                                "Items: \(section.itemLimit)",
                                value: Binding(
                                    get: { section.itemLimit },
                                    set: { limit in
                                        model.updateConfigurableHomeSection(section.id, itemLimit: limit)
                                    }
                                ),
                                in: 4...40,
                                step: 4
                            )

                            Picker("Artwork", selection: Binding(
                                get: { section.artworkShape },
                                set: { shape in
                                    model.updateConfigurableHomeSection(section.id, artworkShape: shape)
                                }
                            )) {
                                ForEach(HomeArtworkShape.allCases, id: \.self) { shape in
                                    Text(shape.rawValue.capitalized).tag(shape)
                                }
                            }
                            .frame(width: 140)
                        }
                        .pickerStyle(.menu)
                        .disabled(!section.isEnabled)
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
    let items: [MediaItemRef]
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
    let item: MediaItemRef
    let tint: Color

    var body: some View {
        Group {
            if item.kind == .song {
                Button {
                    Task { await model.play(item) }
                } label: {
                    cardContent
                }
                .buttonStyle(.plain)
            } else if item.kind == .album || item.kind == .playlist || item.kind == .artist {
                NavigationLink(value: item) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await model.play(item) }
                } label: {
                    cardContent
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                ArtworkThumbnail(url: item.artworkURL, artwork: item.artwork, size: 220, symbolName: item.symbolName)
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
}

struct ArtworkThumbnail: View {
    let url: URL?
    let artwork: Artwork?
    let size: CGFloat
    let symbolName: String
    let shape: HomeArtworkShape

    @State private var artworkImage: NSImage?
    @State private var artworkLoadFailed = false

    init(url: URL?, artwork: Artwork? = nil, size: CGFloat, symbolName: String = "music.note", shape: HomeArtworkShape = .rounded) {
        self.url = url
        self.artwork = artwork
        self.size = size
        self.symbolName = symbolName
        self.shape = shape
    }

    var body: some View {
        ZStack {
            artworkPath
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

            if let artwork {
                ArtworkImage(artwork, width: size, height: size)
                    .scaledToFill()
                    .clipShape(artworkPath)
            } else if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(artworkPath)
            } else if url != nil && !artworkLoadFailed {
                ProgressView()
            } else {
                fallbackGlyph
            }
        }
        .frame(width: size, height: size)
        .clipShape(artworkPath)
        .clipped()
        .task(id: url) {
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        artworkImage = nil
        artworkLoadFailed = false

        guard let url, artwork == nil else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }
            let image = NSImage(data: data)
            artworkImage = image
            artworkLoadFailed = image == nil
        } catch {
            guard !Task.isCancelled else { return }
            artworkLoadFailed = true
        }
    }

    private var artworkPath: AnyShape {
        switch shape {
        case .square:
            AnyShape(Rectangle())
        case .rounded:
            AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .circle:
            AnyShape(Circle())
        }
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
