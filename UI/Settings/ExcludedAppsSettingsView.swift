import AppKit
import KeyboardShortcuts
import LocalAuthentication
import os.log
import SaneUI
import SwiftUI

// MARK: - Excluded Apps (Row-based, matches design language)

struct ExcludedAppsInline: View {
    @Binding var excludedApps: [String]
    var requireAuthForRemoval: Bool = false
    var authenticate: ((String, @escaping () -> Void) -> Void)?
    @State private var selectedExcludedAppBundleID: String?
    @FocusState private var focusedKeyboardTarget: KeyboardTarget?

    private struct AppPreset: Identifiable {
        let label: String
        let bundleID: String
        var id: String { bundleID }
    }

    enum KeyboardTarget: Hashable {
        case addButton
        case preset(String)
        case row(String)
    }

    private static let presets = [
        AppPreset(label: "Alfred", bundleID: "com.runningwithcrayons.Alfred"),
        AppPreset(label: "Raycast", bundleID: "com.raycast.macos"),
        AppPreset(label: "1Password", bundleID: "com.1password.1password"),
        AppPreset(label: "Bitwarden", bundleID: "com.bitwarden.desktop")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Excluded Apps")
                Spacer()
                Button("Add App...") {
                    focusedKeyboardTarget = .addButton
                    browseForApp()
                }
                .buttonStyle(ClipActionButtonStyle())
                .controlSize(.small)
                .keyboardShortcut("n", modifiers: .command)
                .focused($focusedKeyboardTarget, equals: .addButton)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
                    GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(Self.presets) { preset in
                    presetButton(label: preset.label, bundleID: preset.bundleID)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if excludedApps.isEmpty {
                HStack {
                    Text("Add password managers, launchers, or any app you never want saved to history.")
                        .font(.callout)
                        .foregroundStyle(clipReadableSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                HStack {
                    Text("Clips from these apps are never saved to history.")
                        .font(.callout)
                        .foregroundStyle(clipReadableSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                // App rows
                ForEach(excludedApps, id: \.self) { bundleID in
                    CompactDivider()
                    ExcludedAppRow(
                        bundleID: bundleID,
                        isSelected: selectedExcludedAppBundleID == bundleID,
                        onSelect: {
                            selectedExcludedAppBundleID = bundleID
                            focusedKeyboardTarget = .row(bundleID)
                        },
                        onRemove: {
                            removeApp(bundleID)
                        }
                    )
                }
            }
        }
        .focusable()
        .onAppear {
            syncExcludedAppSelection()
            handleDeferredExcludedAppRequest()
        }
        .onChange(of: excludedApps) { _, _ in
            syncExcludedAppSelection()
        }
        .onMoveCommand { direction in
            handleMove(direction)
        }
        .onDeleteCommand {
            guard case let .row(bundleID) = focusedKeyboardTarget else { return }
            removeApp(bundleID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsAddExcludedAppRequested)) { _ in
            handleDeferredExcludedAppRequest()
        }
    }

    @ViewBuilder
    private func presetButton(label: String, bundleID: String) -> some View {
        let exists = excludedApps.contains(bundleID)
        Button {
            guard !exists else { return }
            focusedKeyboardTarget = .preset(bundleID)
            withAnimation(.easeInOut(duration: 0.2)) {
                excludedApps.append(bundleID)
            }
        } label: {
            HStack(spacing: 8) {
                Image(nsImage: appIcon(for: bundleID))
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: 6)

                Image(systemName: exists ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(exists ? .green : .white)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(ClipActionButtonStyle(prominent: exists, compact: true))
        .focused($focusedKeyboardTarget, equals: .preset(bundleID))
    }

    private func appIcon(for bundleID: String) -> NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            let fallback = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
            fallback.size = NSSize(width: 16, height: 16)
            return fallback
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    private func removeApp(_ bundleID: String) {
        if requireAuthForRemoval, let authenticate {
            authenticate("Authenticate to remove app from exclusion list") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    excludedApps.removeAll { $0 == bundleID }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                excludedApps.removeAll { $0 == bundleID }
            }
        }
    }

    nonisolated static func selectedBundleID(fromSelectedAppURL url: URL) -> String? {
        guard url.pathExtension == "app" else { return nil }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleID.isEmpty
        else { return nil }
        return bundleID
    }

    nonisolated static func updatedExcludedApps(afterAdding bundleID: String, to excludedApps: [String]) -> [String] {
        guard !excludedApps.contains(bundleID) else { return excludedApps }
        return excludedApps + [bundleID]
    }

    nonisolated static func nextExcludedAppSelection(current: String?, excludedApps: [String], direction: Int) -> String? {
        guard !excludedApps.isEmpty else { return nil }
        guard direction != 0 else { return current ?? excludedApps.first }

        guard let current, let currentIndex = excludedApps.firstIndex(of: current) else {
            return direction > 0 ? excludedApps.first : excludedApps.last
        }

        let nextIndex = max(0, min(excludedApps.count - 1, currentIndex + direction))
        return excludedApps[nextIndex]
    }

    @MainActor
    private func addSelectedApp(from url: URL) {
        guard let bundleID = Self.selectedBundleID(fromSelectedAppURL: url) else {
            showSettingsWarning(
                message: "Invalid App Selection",
                info: "Please choose a single .app bundle from Applications."
            )
            return
        }
        let updated = Self.updatedExcludedApps(afterAdding: bundleID, to: excludedApps)
        guard updated != excludedApps else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            excludedApps = updated
        }
        selectedExcludedAppBundleID = bundleID
        focusedKeyboardTarget = .row(bundleID)
    }

    private func browseForApp() {
        settingsLogger.info("Excluded Apps Add App invoked")
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Select an app to exclude from clipboard history"

        presentOpenPanel(panel) { url in
            addSelectedApp(from: url)
        }
    }

    private func syncExcludedAppSelection() {
        guard !excludedApps.isEmpty else {
            selectedExcludedAppBundleID = nil
            if case .some(.row) = focusedKeyboardTarget {
                focusedKeyboardTarget = .addButton
            }
            return
        }

        if let selectedExcludedAppBundleID, excludedApps.contains(selectedExcludedAppBundleID) {
            return
        }

        selectedExcludedAppBundleID = excludedApps.first
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            guard let next = Self.nextExcludedAppSelection(
                current: selectedExcludedAppBundleID,
                excludedApps: excludedApps,
                direction: -1
            ) else { return }
            selectedExcludedAppBundleID = next
            focusedKeyboardTarget = .row(next)
        case .down:
            guard let next = Self.nextExcludedAppSelection(
                current: selectedExcludedAppBundleID,
                excludedApps: excludedApps,
                direction: 1
            ) else { return }
            selectedExcludedAppBundleID = next
            focusedKeyboardTarget = .row(next)
        case .left:
            moveHeaderFocus(step: -1)
        case .right:
            moveHeaderFocus(step: 1)
        default:
            break
        }
    }

    private func moveHeaderFocus(step: Int) {
        let headerTargets: [KeyboardTarget] = [.addButton] + Self.presets.map { .preset($0.bundleID) }

        let currentTarget: KeyboardTarget
        switch focusedKeyboardTarget {
        case .some(.addButton):
            currentTarget = .addButton
        case let .some(.preset(bundleID)):
            currentTarget = .preset(bundleID)
        default:
            currentTarget = .addButton
        }

        guard let currentIndex = headerTargets.firstIndex(of: currentTarget) else {
            focusedKeyboardTarget = .addButton
            return
        }

        let nextIndex = max(0, min(headerTargets.count - 1, currentIndex + step))
        focusedKeyboardTarget = headerTargets[nextIndex]
    }

    private func handleDeferredExcludedAppRequest() {
        guard SettingsWindowController.consumePendingAction(.excludedAppPicker) else { return }
        focusedKeyboardTarget = .addButton
        browseForApp()
    }
}

// MARK: - Excluded App Row

struct ExcludedAppRow: View {
    let bundleID: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false

    private var appName: String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID.components(separatedBy: ".").last ?? bundleID
        }
        if let bundle = Bundle(url: appURL) {
            if let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String {
                return name
            }
            if let name = bundle.infoDictionary?["CFBundleName"] as? String {
                return name
            }
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    private var appIcon: NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            let fallback = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
            fallback.size = NSSize(width: 18, height: 18)
            return fallback
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(appName)
                    .foregroundStyle(.white)
                    .font(.system(size: 13, weight: .semibold))

                Text(bundleID)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(clipReadableMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            Button("Remove") {
                onRemove()
            }
            .buttonStyle(ClipActionButtonStyle(destructive: isHovering, compact: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.clipBlue.opacity(0.16) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clipBlue.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovering = $0 }
    }
}
