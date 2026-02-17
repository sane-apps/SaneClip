import SwiftUI

/// Settings tab for iOS app with brand styling
struct SettingsTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

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

                    if !coordinator.connectedDevices.isEmpty {
                        ForEach(coordinator.connectedDevices, id: \.self) { device in
                            settingsRow(icon: "desktopcomputer", label: device)
                        }
                    }
                }
            #else
                HStack(spacing: rowSpacing) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: rowIcon))
                        .foregroundStyle(.teal)
                        .frame(width: iconFrame, alignment: .center)
                    Text("Last Synced")
                        .font(rowText)
                        .foregroundStyle(.white)
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
                        .foregroundStyle(.teal)
                        .frame(width: iconFrame, alignment: .center)
                    Text("Sync Now")
                        .font(rowText)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.teal)
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

            Link(destination: URL(string: "mailto:hi@saneapps.com")!) {
                settingsRow(icon: "envelope", label: "Contact Support")
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
                Text("Save clipboard items with the + button or Share menu. Tap any item to copy it back. Enable iCloud Sync to share your clipboard between your Mac and iOS devices.")
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
        iconColor: Color = .teal
    ) -> some View {
        HStack(spacing: rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: rowIcon))
                .foregroundStyle(iconColor)
                .frame(width: iconFrame, alignment: .center)
            Text(label)
                .font(rowText)
                .foregroundStyle(.white)
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
            }
        }
    #endif
}

#Preview {
    SettingsTab()
        .environmentObject(ClipboardHistoryViewModel())
}
