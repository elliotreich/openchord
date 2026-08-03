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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                resultSections
            }
            .padding(24)
        }
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
        Image(systemName: "music.note")
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
