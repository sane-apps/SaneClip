import SwiftUI

/// Settings tab for iOS app with brand styling
struct SettingsTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel

    var body: some View {
        NavigationStack {
            List {
                // Sync Status Section
                Section {
                    HStack {
                        Label("Last Synced", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Color.clipBlue)
                        Spacer()
                        if let lastSync = viewModel.lastSyncTime {
                            Text(lastSync, style: .relative)
                                .foregroundStyle(Color.textStone)
                        } else {
                            Text("Never")
                                .foregroundStyle(Color.textStone)
                        }
                    }

                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        HStack {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color.clipBlue)
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                } header: {
                    Text("Sync")
                }

                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(Color.clipBlue)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(Color.textStone)
                    }

                    Link(destination: URL(string: "https://saneclip.com")!) {
                        Label("Website", systemImage: "globe")
                    }

                    Link(destination: URL(string: "https://saneclip.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("About")
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SaneClip iOS")
                            .font(.headline)
                        Text("View and copy your clipboard history synced from your Mac. Items copied here are added to your Mac's clipboard history.")
                            .font(.caption)
                            .foregroundStyle(Color.textStone)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How It Works")
                }
            }
            .navigationTitle("Settings")
        }
        .tint(Color.clipBlue)
    }
}

#Preview {
    SettingsTab()
        .environmentObject(ClipboardHistoryViewModel())
}
