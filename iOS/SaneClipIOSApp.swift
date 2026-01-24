import SwiftUI

@main
struct SaneClipIOSApp: App {
    @StateObject private var viewModel = ClipboardHistoryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .tint(Color.clipBlue)
        }
    }
}

/// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel

    var body: some View {
        TabView {
            HistoryTab()
                .tabItem {
                    Label("History", systemImage: "doc.on.clipboard")
                }

            PinnedTab()
                .tabItem {
                    Label("Pinned", systemImage: "pin.fill")
                }

            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardHistoryViewModel())
}
