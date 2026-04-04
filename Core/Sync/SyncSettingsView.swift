#if ENABLE_SYNC

    import SaneUI
    import SwiftUI

    private let syncReadableSecondary = Color.white.opacity(0.88)

    struct SyncSettingsView: View {
        @State private var coordinator = SyncCoordinator.shared
        @State private var showResetConfirmation = false

        init(coordinator: SyncCoordinator = .shared) {
            _coordinator = State(initialValue: coordinator)
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CompactSection("Sync", icon: "arrow.triangle.2.circlepath.icloud", iconColor: SaneSettingsIconSemantic.sync.color) {
                        CompactToggle(
                            label: "iCloud Sync",
                            icon: "arrow.triangle.2.circlepath.icloud",
                            iconColor: SaneSettingsIconSemantic.sync.color,
                            isOn: $coordinator.isSyncEnabled
                        )

                        Text("Share clipboard history across your Apple devices")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(syncReadableSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.92)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)

                        if coordinator.isSyncEnabled {
                            CompactDivider()
                            CompactRow("Status") {
                                StatusBadge(
                                    coordinator.syncStatus.rawValue,
                                    color: statusColor,
                                    icon: statusSymbol
                                )
                            }
                        }
                    }

                    CompactSection("Status", icon: "chart.pie", iconColor: SaneSettingsIconSemantic.storage.color) {
                        diagnosticsRow("Local Items", value: "\(coordinator.localItemCount)", icon: "doc.on.clipboard")

                        if let remoteItemCount = coordinator.remoteItemCount {
                            CompactDivider()
                            diagnosticsRow("Synced Items", value: "\(remoteItemCount)", icon: "arrow.triangle.2.circlepath")
                        }

                        CompactDivider()
                        diagnosticsRow("Connected Devices", value: "\(coordinator.connectedDevices.count)", icon: "desktopcomputer")

                        CompactDivider()
                        diagnosticsRow(
                            "Last Sync",
                            value: coordinator.lastSyncDate.map {
                                RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
                            } ?? "Never",
                            icon: "clock"
                        )
                    }

                    if coordinator.isSyncEnabled, !coordinator.connectedDevices.isEmpty {
                        CompactSection("Connected Devices", icon: "desktopcomputer", iconColor: Color.clipBlue) {
                            ForEach(Array(coordinator.connectedDevices.enumerated()), id: \.offset) { index, device in
                                if index > 0 {
                                    CompactDivider()
                                }

                                HStack(spacing: 10) {
                                    Image(systemName: deviceIcon(for: device))
                                        .foregroundStyle(Color.clipBlue)
                                        .frame(width: 16)
                                    Text(device)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                        }
                    }

                    if coordinator.canResetSyncState {
                        CompactSection("Actions", icon: "gearshape.2", iconColor: .white) {
                            HStack(spacing: 12) {
                                Text("Reset iCloud Sync")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Spacer(minLength: 12)
                                Button("Reset Sync") {
                                    showResetConfirmation = true
                                }
                                .buttonStyle(SaneActionButtonStyle(destructive: true, compact: true))
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                            Text("Clears saved sync state on this device and reconnects to iCloud. Your local clipboard history stays on this device.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(syncReadableSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                        }
                    }

                    CompactSection("About Sync", icon: "icloud", iconColor: Color.clipBlue) {
                        infoRow("End-to-end encrypted when history encryption is enabled", icon: "lock.shield", color: .green)
                        CompactDivider()
                        infoRow("Uses your private iCloud storage — no third-party servers", icon: "icloud", color: Color.clipBlue)
                        CompactDivider()
                        infoRow("Images are synced as compressed PNG data", icon: "photo", color: syncReadableSecondary)
                    }
                }
                .padding(20)
            }
            .alert("Reset iCloud Sync?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset Sync", role: .destructive) {
                    coordinator.resetSyncStatePreservingLocalHistory()
                }
            } message: {
                Text("This clears saved sync state on this device and reconnects to iCloud sync. Your local clipboard history stays on this device.")
            }
        }

        private var statusSymbol: String {
            switch coordinator.syncStatus {
            case .idle:
                "checkmark.circle.fill"
            case .syncing:
                "arrow.triangle.2.circlepath"
            case .error:
                "exclamationmark.triangle.fill"
            case .disabled:
                "pause.circle.fill"
            case .noAccount:
                "person.crop.circle.badge.exclamationmark"
            case .unavailable:
                "icloud.slash"
            }
        }

        private var statusColor: Color {
            switch coordinator.syncStatus {
            case .idle:
                .green
            case .syncing:
                Color.clipBlue
            case .error:
                .red
            case .disabled:
                Color.white.opacity(0.35)
            case .noAccount, .unavailable:
                .orange
            }
        }

        private func diagnosticsRow(_ label: String, value: String, icon: String) -> some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color.clipBlue)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(syncReadableSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }

        private func infoRow(_ text: String, icon: String, color: Color) -> some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
