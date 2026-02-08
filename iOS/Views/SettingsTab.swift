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
                                .foregroundStyle(Color.clipBlue)
                        }
                        .toggleStyle(.switch)

                        if coordinator.isSyncEnabled {
                            HStack {
                                Label("Status", systemImage: "circle.fill")
                                    .foregroundStyle(syncStatusColor)
                                Spacer()
                                Text(coordinator.syncStatus.rawValue)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Label("Last Synced", systemImage: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(Color.clipBlue)
                                Spacer()
                                if let lastSync = coordinator.lastSyncDate {
                                    Text(lastSync, style: .relative)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Never")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if !coordinator.connectedDevices.isEmpty {
                                ForEach(coordinator.connectedDevices, id: \.self) { device in
                                    Label(device, systemImage: "desktopcomputer")
                                        .foregroundStyle(Color.clipBlue)
                                }
                            }
                        }
                    #else
                        HStack {
                            Label("Last Synced", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.clipBlue)
                            Spacer()
                            if let lastSync = viewModel.lastSyncTime {
                                Text(lastSync, style: .relative)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Never")
                                    .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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
                        Text("View and copy your clipboard history synced from your Mac. Enable iCloud Sync to keep your clipboard in sync across all your devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
