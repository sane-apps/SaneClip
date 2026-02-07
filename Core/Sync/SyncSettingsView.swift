#if ENABLE_SYNC

    import SwiftUI

    struct SyncSettingsView: View {
        @State private var coordinator = SyncCoordinator.shared

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Enable/disable toggle
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $coordinator.isSyncEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("iCloud Sync")
                                        .font(.headline)
                                    Text("Sync clipboard history across your Apple devices")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)

                            if coordinator.isSyncEnabled {
                                Divider()

                                // Status row
                                HStack {
                                    Label {
                                        Text("Status")
                                    } icon: {
                                        statusIcon
                                    }
                                    Spacer()
                                    Text(coordinator.syncStatus.rawValue)
                                        .foregroundStyle(.secondary)
                                }

                                // Last sync
                                if let lastSync = coordinator.lastSyncDate {
                                    HStack {
                                        Label("Last Sync", systemImage: "clock")
                                        Spacer()
                                        Text(lastSync, style: .relative)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(4)
                    }

                    // Connected devices
                    if coordinator.isSyncEnabled, !coordinator.connectedDevices.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Connected Devices")
                                    .font(.headline)

                                ForEach(coordinator.connectedDevices, id: \.self) { device in
                                    HStack {
                                        Image(systemName: deviceIcon(for: device))
                                            .foregroundStyle(Color.clipBlue)
                                        Text(device)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }

                    // Info section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Sync")
                                .font(.headline)

                            Label {
                                Text("End-to-end encrypted when history encryption is enabled")
                            } icon: {
                                Image(systemName: "lock.shield")
                                    .foregroundStyle(.green)
                            }
                            .font(.caption)

                            Label {
                                Text("Uses your private iCloud storage — no third-party servers")
                            } icon: {
                                Image(systemName: "icloud")
                                    .foregroundStyle(Color.clipBlue)
                            }
                            .font(.caption)

                            Label {
                                Text("Images are synced as compressed PNG data")
                            } icon: {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding(4)
                    }
                }
                .padding(20)
            }
        }

        @ViewBuilder
        private var statusIcon: some View {
            switch coordinator.syncStatus {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.clipBlue)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .disabled:
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.secondary)
            case .noAccount:
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
            }
        }

        private func deviceIcon(for device: String) -> String {
            let lower = device.lowercased()
            if lower.contains("mac") || lower.contains("imac") || lower.contains("macbook") {
                return "desktopcomputer"
            } else if lower.contains("ipad") {
                return "ipad"
            } else {
                return "iphone"
            }
        }
    }

#endif
