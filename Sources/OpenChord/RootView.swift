import SwiftUI
@preconcurrency import MusicKit

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(model.theme.accent)
                    Text("OpenChord")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            columnVisibility = .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .buttonStyle(.plain)
                    .help("Collapse sidebar")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()

                List(selection: $model.selectedSection) {
                    ForEach(AppSection.allCases) { section in
                        Label(section.title, systemImage: section.symbolName)
                            .tag(section)
                    }
                }
            }
            .toolbar(.hidden, for: .windowToolbar)
        } detail: {
            ZStack {
                themeBackdrop
                switch model.selectedSection {
                case .home:
                    HomeView()
                case .search:
                    SearchView()
                case .library:
                    LibraryView()
                case .queue:
                    QueueView()
                case .settings:
                    SettingsView()
                }
            }
            .animation(.easeInOut(duration: 0.24), value: model.selectedSection)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PlayerBarView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if columnVisibility == .detailOnly {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            columnVisibility = .all
                        }
                    } label: {
                        Label("Show Sidebar", systemImage: "sidebar.left")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .preferredColorScheme(model.theme.preferredColorScheme)
    }

    private var themeBackdrop: some View {
        LinearGradient(
            colors: model.theme.backgroundGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            RadialGradient(
                colors: [
                    model.theme.accent.opacity(0.22),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 450
            )
            .blendMode(.screen)
            .ignoresSafeArea()
        }
    }
}
