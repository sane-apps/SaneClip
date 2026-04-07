import SaneUI
import SwiftUI

/// Settings tab for iOS app with brand styling
struct SettingsTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showResetSyncConfirmation = false

    private var isIPad: Bool { sizeClass == .regular }

    // MARK: - Proportional Type Scale

    // iPad scale: 1.5× base iOS sizes, maintaining ratio between levels
    // iPhone: standard iOS Dynamic Type sizes
    private var rowText: Font { .system(size: isIPad ? 26 : 17) }
    private var rowIcon: CGFloat { isIPad ? 22 : 16 }
    private var iconFrame: CGFloat { isIPad ? 34 : 24 }
    private var sectionHeader: Font { .system(size: isIPad ? 22 : 13, weight: .semibold) }
    private var infoTitle: Font { .system(size: isIPad ? 32 : 17, weight: .bold) }
    private var infoBody: Font { .system(size: isIPad ? 24 : 15) }
    private var rowSpacing: CGFloat { isIPad ? 16 : 10 }
    private var rowPadding: CGFloat { isIPad ? 6 : 0 }

    #if ENABLE_SYNC
        @State private var coordinator = SyncCoordinator.shared
    #endif

    var body: some View {
        NavigationStack {
            List {
                syncSection
                aboutSection
                infoSection
            }
            .listStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarBackground(.visible, for: .navigationBar)
            #if ENABLE_SYNC
                .alert("Reset iCloud Sync?", isPresented: $showResetSyncConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset Sync", role: .destructive) {
                        coordinator.resetSyncStatePreservingLocalHistory()
                    }
                } message: {
                    Text("This clears saved sync state on this device and reconnects to iCloud sync. Your local clipboard history stays on this device.")
                }
            #endif
        }
    }

    // MARK: - Sections

    private var syncSection: some View {
        Section {
            #if ENABLE_SYNC
                Toggle(isOn: $coordinator.isSyncEnabled) {
                    settingsRow(icon: "icloud", label: "iCloud Sync")
                }
                .toggleStyle(.switch)

                if coordinator.isSyncEnabled {
                    settingsRow(
                        icon: "circle.fill",
                        label: "Status",
                        value: coordinator.syncStatus.rawValue,
                        iconColor: syncStatusColor
                    )

                    settingsRow(
                        icon: "arrow.triangle.2.circlepath",
                        label: "Last Synced",
                        value: coordinator.lastSyncDate.map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) } ?? "Never"
                    )

                    settingsRow(
                        icon: "doc.on.clipboard",
                        label: "Local Items",
                        value: "\(coordinator.localItemCount)"
                    )

                    if let remoteItemCount = coordinator.remoteItemCount {
                        settingsRow(
                            icon: "tray.full",
                            label: "Synced Items",
                            value: "\(remoteItemCount)"
                        )
                    }

                    if !coordinator.connectedDevices.isEmpty {
                        settingsRow(
                            icon: "desktopcomputer",
                            label: "Connected Devices",
                            value: "\(coordinator.connectedDevices.count)"
                        )
                        ForEach(coordinator.connectedDevices, id: \.self) { device in
                            settingsRow(icon: "desktopcomputer", label: device)
                        }
                    }

                    if coordinator.canResetSyncState {
                        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                            HStack(spacing: rowSpacing) {
                                Text("Reset iCloud Sync")
                                    .font(rowText.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Spacer(minLength: isIPad ? 20 : 12)
                                Button("Reset Sync") {
                                    showResetSyncConfirmation = true
                                }
                                .buttonStyle(SaneActionButtonStyle(destructive: true, compact: true))
                            }

                            Text("Clears saved sync state on this device and reconnects to iCloud. Your local clipboard history stays on this device.")
                                .font(infoBody)
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(maxWidth: isIPad ? 720 : 340, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, isIPad ? 10 : 6)
                    }
                }
            #else
                HStack(spacing: rowSpacing) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: rowIcon))
                        .foregroundStyle(Color.clipBlue)
                        .frame(width: iconFrame, alignment: .center)
                    Text("Last Synced")
                        .font(rowText)
                        .foregroundStyle(Color.clipBlue)
                    Spacer()
                    if let lastSync = viewModel.lastSyncTime {
                        Text(lastSync, style: .relative)
                            .font(rowText)
                            .foregroundStyle(.white.opacity(0.9))
                    } else {
                        Text("Never")
                            .font(rowText)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.vertical, rowPadding)
            #endif

            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: rowSpacing) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: rowIcon))
                        .foregroundStyle(Color.clipBlue)
                        .frame(width: iconFrame, alignment: .center)
                    Text("Sync Now")
                        .font(rowText)
                        .foregroundStyle(Color.clipBlue)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color.clipBlue)
                    }
                }
                .padding(.vertical, rowPadding)
            }
            .disabled(viewModel.isLoading)
        } header: {
            Text("Sync")
                .font(sectionHeader)
                .foregroundColor(.white)
                .textCase(nil)
                .padding(.bottom, isIPad ? 8 : 0)
        }
    }

    private var aboutSection: some View {
        Section {
            settingsRow(
                icon: "info.circle",
                label: "Version",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )

            Link(destination: URL(string: "https://saneclip.com")!) {
                settingsRow(icon: "globe", label: "Website")
            }

            Link(destination: URL(string: "https://saneclip.com/privacy")!) {
                settingsRow(icon: "hand.raised", label: "Privacy Policy")
            }
        } header: {
            Text("About")
                .font(sectionHeader)
                .foregroundColor(.white)
                .textCase(nil)
                .padding(.bottom, isIPad ? 8 : 0)
        }
    }

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: isIPad ? 20 : 8) {
                Text("SaneClip iOS")
                    .font(infoTitle)
                Text("View and copy your clipboard history synced from your Mac. Enable iCloud Sync to keep your clipboard in sync across all your devices.")
                    .font(infoBody)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.vertical, isIPad ? 16 : 4)
        } header: {
            Text("How It Works")
                .font(sectionHeader)
                .foregroundColor(.white)
                .textCase(nil)
                .padding(.bottom, isIPad ? 8 : 0)
        }
    }

    // MARK: - Row Helper

    private func settingsRow(
        icon: String,
        label: String,
        value: String? = nil,
        iconColor: Color = .clipBlue,
        labelColor: Color = .clipBlue
    ) -> some View {
        HStack(spacing: rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: rowIcon))
                .foregroundStyle(iconColor)
                .frame(width: iconFrame, alignment: .center)
            Text(label)
                .font(rowText)
                .foregroundStyle(labelColor)
            Spacer()
            if let value {
                Text(value)
                    .font(rowText)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.vertical, rowPadding)
    }

    #if ENABLE_SYNC
        private var syncStatusColor: Color {
            switch coordinator.syncStatus {
            case .idle: .green
            case .syncing: .blue
            case .error: .red
            case .disabled: .gray
            case .noAccount: .orange
            case .unavailable: .orange
            }
        }
    #endif
}

#Preview {
    SettingsTab()
        .environmentObject(ClipboardHistoryViewModel())
}

extension SaneDiagnosticsService {
    static let shared = SaneDiagnosticsService(
        appName: "SaneClip",
        subsystem: "com.saneclip.app",
        githubRepo: "sane-apps/SaneClip",
        settingsCollector: collectSaneClipIOSSettings
    )

    private static func collectSaneClipIOSSettings() async -> String {
        let defaults = UserDefaults.standard
        var lines = [
            "hasCompletedOnboardingIOS: \(defaults.bool(forKey: "hasCompletedOnboardingIOS"))"
        ]

        #if ENABLE_SYNC
            let syncDiagnostics = await MainActor.run { () -> [String] in
                let coordinator = SyncCoordinator.shared
                return [
                    "syncEnabled: \(coordinator.isSyncEnabled)",
                    "syncStatus: \(coordinator.syncStatus.rawValue)",
                    "connectedDeviceCount: \(coordinator.connectedDevices.count)",
                    "lastSyncDate: \(coordinator.lastSyncDate?.description ?? "nil")"
                ]
            }
            lines.append(contentsOf: syncDiagnostics)
        #else
            lines.append("syncEnabled: false")
            lines.append("syncStatus: unavailable")
        #endif

        return lines.joined(separator: "\n")
    }
}
