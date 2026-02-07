import SwiftUI

@main
struct SaneClipIOSApp: App {
    @StateObject private var viewModel = ClipboardHistoryViewModel()
    @AppStorage("hasCompletedOnboardingIOS") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .tint(Color.clipBlue)
                .fullScreenCover(isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { if $0 { hasCompletedOnboarding = false } }
                )) {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
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
