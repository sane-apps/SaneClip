import SwiftUI

/// Settings tab for iOS app with brand styling
struct SettingsTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel

    #if ENABLE_SYNC
        @State private var coordinator = SyncCoordinator.shared
    #endif

    var body: some View {
        NavigationStack {
            List {
                // Sync Section
                Section {
                    #if ENABLE_SYNC
                        Toggle(isOn: $coordinator.isSyncEnabled) {
                            Label("iCloud Sync", systemImage: "icloud")
                                .foregroundStyle(.teal)
                        }
                        .toggleStyle(.switch)

                        if coordinator.isSyncEnabled {
                            HStack {
                                Label("Status", systemImage: "circle.fill")
                                    .foregroundStyle(syncStatusColor)
                                Spacer()
                                Text(coordinator.syncStatus.rawValue)
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                            HStack {
                                Label("Last Synced", systemImage: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.teal)
                                Spacer()
                                if let lastSync = coordinator.lastSyncDate {
                                    Text(lastSync, style: .relative)
                                        .foregroundStyle(.white.opacity(0.9))
                                } else {
                                    Text("Never")
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }

                            if !coordinator.connectedDevices.isEmpty {
                                ForEach(coordinator.connectedDevices, id: \.self) { device in
                                    Label(device, systemImage: "desktopcomputer")
                                        .foregroundStyle(.teal)
                                }
                            }
                        }
                    #else
                        HStack {
                            Label("Last Synced", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.teal)
                            Spacer()
                            if let lastSync = viewModel.lastSyncTime {
                                Text(lastSync, style: .relative)
                                    .foregroundStyle(.white.opacity(0.9))
                            } else {
                                Text("Never")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    #endif

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
                                    .tint(.teal)
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                } header: {
                    Text("Sync")
                        .foregroundStyle(.white)
                }

                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(.teal)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Link(destination: URL(string: "mailto:hi@saneapps.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }

                    Link(destination: URL(string: "https://saneclip.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("About")
                        .foregroundStyle(.white)
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SaneClip iOS")
                            .font(.headline)
                        Text("Save clipboard items with the + button or Share menu. Tap any item to copy it back. Enable iCloud Sync to share your clipboard between your Mac and iOS devices.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How It Works")
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    #if ENABLE_SYNC
        private var syncStatusColor: Color {
            switch coordinator.syncStatus {
            case .idle: .green
            case .syncing: .blue
            case .error: .red
            case .disabled: .gray
            case .noAccount: .orange
            }
        }
    #endif
}

#Preview {
    SettingsTab()
        .environmentObject(ClipboardHistoryViewModel())
}
