import SwiftUI

@main
struct SaneClipIOSApp: App {
    @StateObject private var viewModel = ClipboardHistoryViewModel()
    @AppStorage("hasCompletedOnboardingIOS") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .tint(.teal)
                .preferredColorScheme(.dark)
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab = 0

    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        if isIPad {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad: Custom large tab bar

    private var iPadLayout: some View {
        VStack(spacing: 0) {
            // Large custom tab bar
            HStack(spacing: 28) {
                iPadTabButton("History", icon: "doc.on.clipboard", index: 0)
                iPadTabButton("Pinned", icon: "pin.fill", index: 1)
                iPadTabButton("Settings", icon: "gear", index: 2)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)

            // Tab content
            Group {
                switch selectedTab {
                case 1: PinnedTab()
                case 2: SettingsTab()
                default: HistoryTab()
                }
            }
        }
    }

    private func iPadTabButton(_ title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .font(.system(size: 28))
            .foregroundStyle(isSelected ? .teal : .white.opacity(0.9))
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.teal.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
    }

    // MARK: - iPhone: Standard TabView

    private var iPhoneLayout: some View {
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
