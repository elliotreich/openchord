import SwiftUI

@main
struct OpenChordApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
