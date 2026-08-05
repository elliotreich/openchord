import SwiftUI
@preconcurrency import MusicKit

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .navigationTitle("OpenChord")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
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
