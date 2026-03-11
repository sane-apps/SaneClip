// swiftlint:disable file_length
import KeyboardShortcuts
import LocalAuthentication
import SaneUI
import SwiftUI
import os.log

private let settingsLogger = Logger(subsystem: "com.saneclip.app", category: "Settings")

// MARK: - Notifications

extension Notification.Name {
    static let menuBarIconChanged = Notification.Name("menuBarIconChanged")
    static let historySearchShortcutRequested = Notification.Name("historySearchShortcutRequested")
    static let settingsTabShortcutRequested = Notification.Name("settingsTabShortcutRequested")
    static let settingsAddExcludedAppRequested = Notification.Name("settingsAddExcludedAppRequested")
}

// MARK: - Settings View

struct SettingsView: View {
    var licenseService: LicenseService?
    @State private var selectedTab: SettingsTab?
    @FocusState private var focusedPane: SettingsPane?

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case snippets = "Snippets"
        #if ENABLE_SYNC
            case sync = "Sync"
        #endif
        case storage = "Storage"
        case license = "License"
        case about = "About"

        var id: String { rawValue }
    }

    enum SettingsPane: Hashable {
        case sidebar
    }

    @Environment(\.colorScheme) private var colorScheme

    init(licenseService: LicenseService?, initialTab: SettingsTab? = .general) {
        self.licenseService = licenseService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label {
                        Text(tab.rawValue)
                    } icon: {
                        Image(systemName: icon(for: tab))
                            .foregroundStyle(iconColor(for: tab))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
            .focusable()
            .focused($focusedPane, equals: .sidebar)
        } detail: {
            ZStack {
                // Gradient background for both modes
                SettingsGradientBackground()

                switch selectedTab {
                case .general:
                    GeneralSettingsView(licenseService: licenseService)
                case .shortcuts:
                    ShortcutsSettingsView(licenseService: licenseService)
                case .snippets:
                    SnippetsSettingsView(licenseService: licenseService)
                        .padding(20)
                #if ENABLE_SYNC
                    case .sync:
                        SyncSettingsView()
                #endif
                case .storage:
                    StorageStatsView()
                        .padding(20)
                case .license:
                    if let licenseService {
                        Form {
                            LicenseSettingsView(licenseService: licenseService)
                        }
                        .formStyle(.grouped)
                        .padding(20)
                    }
                case .about:
                    AboutSettingsView()
                case .none:
                    GeneralSettingsView(licenseService: licenseService)
                }
            }
        }
        .groupBoxStyle(GlassGroupBoxStyle())
        .frame(minWidth: 700, minHeight: 450)
        .background(settingsKeyboardShortcuts)
        .onAppear {
            if selectedTab == nil {
                selectedTab = .general
            }
            focusedPane = .sidebar
        }
        .onExitCommand {
            SettingsWindowController.close()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsTabShortcutRequested)) { notification in
            guard let tab = notification.object as? SettingsTab else { return }
            selectedTab = tab
            focusedPane = .sidebar
        }
    }

    private func icon(for tab: SettingsTab) -> String {
        switch tab {
        case .general: "gear"
        case .shortcuts: "keyboard"
        case .snippets: "text.quote"
        #if ENABLE_SYNC
            case .sync: "arrow.triangle.2.circlepath.icloud"
        #endif
        case .storage: "chart.pie"
        case .license: "key"
        case .about: "info.circle"
        }
    }

    private func iconColor(for tab: SettingsTab) -> Color {
        switch tab {
        case .general: .textStone
        case .shortcuts: .clipBlue
        case .snippets: .green
        #if ENABLE_SYNC
            case .sync: .cyan
        #endif
        case .storage: .pinnedOrange
        case .license: .teal
        case .about: .brandSilver
        }
    }

    nonisolated static func tab(forShortcutIndex index: Int) -> SettingsTab? {
        guard SettingsTab.allCases.indices.contains(index) else { return nil }
        return SettingsTab.allCases[index]
    }

    @ViewBuilder
    private var settingsKeyboardShortcuts: some View {
        ZStack {
            ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element.id) { index, tab in
                Button("") {
                    selectedTab = tab
                    focusedPane = .sidebar
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0.001)
                .accessibilityHidden(true)
            }
        }
    }
}

@MainActor
private func preferredPanelHostWindow(explicitWindow: NSWindow? = nil) -> NSWindow? {
    if let explicitWindow, explicitWindow.isVisible {
        return explicitWindow
    }

    if let settingsWindow = SettingsWindowController.presentedWindow {
        return settingsWindow
    }

    if let keyWindow = NSApp.keyWindow, keyWindow.isVisible {
        return keyWindow
    }

    if let mainWindow = NSApp.mainWindow, mainWindow.isVisible {
        return mainWindow
    }

    return NSApp.windows.first(where: \.isVisible)
}

@MainActor
private func presentOpenPanel(_ panel: NSOpenPanel, onSelection: @escaping (URL) -> Void) {
    if NSApp.activationPolicy() == .accessory {
        settingsLogger.info("Presenting open panel modally for accessory app flow")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settingsLogger.info("Accessory open panel completed with selection \(url.path, privacy: .public)")
        onSelection(url)
        return
    }

    if let window = preferredPanelHostWindow() {
        settingsLogger.info(
            "Presenting open panel as sheet on window title=\(window.title, privacy: .public) class=\(String(describing: type(of: window)), privacy: .public)"
        )
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            settingsLogger.info("Open panel completed with selection \(url.path, privacy: .public)")
            onSelection(url)
        }
        return
    }

    settingsLogger.info("Presenting open panel modally without host window")
    guard panel.runModal() == .OK, let url = panel.url else { return }
    settingsLogger.info("Modal open panel completed with selection \(url.path, privacy: .public)")
    onSelection(url)
}

@MainActor
private func presentSavePanel(_ panel: NSSavePanel, onSelection: @escaping (URL) -> Void) {
    if NSApp.activationPolicy() == .accessory {
        settingsLogger.info("Presenting save panel modally for accessory app flow")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settingsLogger.info("Accessory save panel completed with selection \(url.path, privacy: .public)")
        onSelection(url)
        return
    }

    if let window = preferredPanelHostWindow() {
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            onSelection(url)
        }
        return
    }

    guard panel.runModal() == .OK, let url = panel.url else { return }
    onSelection(url)
}

@MainActor
private func showSettingsWarning(message: String, info: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = .warning
    alert.runModal()
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    var licenseService: LicenseService?
    @State private var settings = SettingsModel.shared
    @State private var appPresetBundleID = ""
    @State private var appPresetMode: PasteMode = .standard
    #if !APP_STORE
        @State private var autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
        @State private var updateCheckFrequency = UpdateService.shared.updateCheckFrequency
    #else
        @State private var autoCheckUpdates = false
    #endif
    @State private var isAuthenticating = false

    private var isPro: Bool { licenseService?.isPro == true }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CompactSection("Startup") {
                    SaneLoginItemToggle()
                    CompactDivider()
                    SaneDockIconToggle(showDockIcon: Binding(
                        get: { settings.showInDock },
                        set: { settings.showInDock = $0 }
                    ))
                }

                CompactSection("Appearance") {
                    CompactRow("Menu Bar Icon") {
                        Picker("", selection: Binding(
                            get: { settings.menuBarIcon },
                            set: { settings.menuBarIcon = $0 }
                        )) {
                            Label("List", systemImage: "list.clipboard.fill").tag("list.clipboard.fill")
                            Label("Minimal", systemImage: "doc.plaintext").tag("doc.plaintext")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    CompactDivider()
                    CompactRow("Paste sound") {
                        HStack(spacing: 8) {
                            Picker("", selection: Binding(
                                get: { settings.pasteSound },
                                set: { settings.pasteSound = $0 }
                            )) {
                                ForEach(PasteSound.allCases, id: \.self) { sound in
                                    Text(sound.rawValue).tag(sound)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)

                            Button {
                                settings.pasteSound.play()
                            } label: {
                                Image(systemName: "speaker.wave.2")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(settings.pasteSound == .off)
                            .help("Preview sound")
                        }
                    }
                    CompactDivider()
                    if isPro {
                        CompactToggle(label: "Paste stack: newest first", isOn: Binding(
                            get: { settings.pasteStackReversed },
                            set: { settings.pasteStackReversed = $0 }
                        ))
                        CompactDivider()
                        CompactToggle(label: "Keep stack panel open while pasting", isOn: Binding(
                            get: { settings.keepPasteStackOpenBetweenPastes },
                            set: { settings.keepPasteStackOpenBetweenPastes = $0 }
                        ))
                        CompactDivider()
                        CompactToggle(label: "Auto-close panel when stack is empty", isOn: Binding(
                            get: { settings.autoClosePasteStackWhenEmpty },
                            set: { settings.autoClosePasteStackWhenEmpty = $0 }
                        ))
                        CompactDivider()
                        CompactToggle(label: "Collapse duplicate stack items", isOn: Binding(
                            get: { settings.collapseDuplicatePasteStackItems },
                            set: { settings.collapseDuplicatePasteStackItems = $0 }
                        ))
                        CompactDivider()
                        CompactRow("Default paste mode") {
                            Picker("", selection: Binding(
                                get: { SettingsModel.shared.defaultPasteMode },
                                set: { SettingsModel.shared.defaultPasteMode = $0 }
                            )) {
                                ForEach(PasteMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                        }
                        HStack {
                            Spacer()
                            Text(SettingsModel.shared.defaultPasteMode.description)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)

                        CompactRow("Per-app paste mode") {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    TextField("com.apple.TextEdit", text: $appPresetBundleID)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 190)
                                    Picker("", selection: $appPresetMode) {
                                        ForEach(PasteMode.allCases, id: \.self) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 110)
                                    Button("Save") {
                                        let key = appPresetBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !key.isEmpty else { return }
                                        settings.setPasteMode(appPresetMode, for: key)
                                        appPresetBundleID = ""
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }

                                if settings.perAppPasteModes.isEmpty {
                                    Text("No overrides configured")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(settings.perAppPasteModes.keys.sorted(), id: \.self) { bundleID in
                                        HStack(spacing: 8) {
                                            Text(bundleID)
                                                .font(.system(size: 11, design: .monospaced))
                                                .lineLimit(1)
                                            Spacer(minLength: 8)
                                            Text(settings.perAppPasteModes[bundleID] ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Button("Remove") {
                                                settings.setPasteMode(nil, for: bundleID)
                                            }
                                            .buttonStyle(.plain)
                                            .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    } else {
                        ProLockedRow(label: "Paste stack order (FIFO / LIFO)", feature: .pasteStack, licenseService: licenseService)
                        CompactDivider()
                        ProLockedRow(label: "Default paste mode (Plain / Smart)", feature: .smartPaste, licenseService: licenseService)
                    }
                }

                CompactSection("Security") {
                    CompactToggle(label: "Detect & skip passwords", isOn: Binding(
                        get: { settings.protectPasswords },
                        set: { newValue in
                            if newValue {
                                // Turning ON - no auth needed
                                settings.protectPasswords = true
                            } else {
                                // Turning OFF - always requires auth
                                let reason = "Authenticate to allow password manager copies in history"
                                Task { @MainActor in
                                    if await authenticateForSecurityChange(reason: reason) {
                                        settings.protectPasswords = false
                                    }
                                }
                            }
                        }
                    ))
                    .disabled(isAuthenticating)
                    CompactDivider()
                    if isPro {
                        CompactToggle(label: "Require Touch ID to view history", isOn: Binding(
                            get: { settings.requireTouchID },
                            set: { newValue in
                                if newValue {
                                    // Turning ON - no auth needed
                                    settings.requireTouchID = true
                                } else {
                                    // Turning OFF - always requires auth
                                    Task { @MainActor in
                                        if await authenticateForSecurityChange(reason: "Authenticate to disable Touch ID protection") {
                                            settings.requireTouchID = false
                                        }
                                    }
                                }
                            }
                        ))
                        .disabled(isAuthenticating)
                    } else {
                        ProLockedRow(label: "Require Touch ID to view history", feature: .historyLock, licenseService: licenseService)
                    }
                    CompactDivider()
                    if isPro {
                        CompactToggle(label: "Encrypt history at rest", isOn: Binding(
                            get: { settings.encryptHistory },
                            set: { newValue in
                                if newValue {
                                    // Turning ON encryption - no auth needed
                                    settings.encryptHistory = true
                                } else {
                                    // Turning OFF encryption - requires auth
                                    Task { @MainActor in
                                        if await authenticateForSecurityChange(reason: "Authenticate to disable history encryption") {
                                            settings.encryptHistory = false
                                        }
                                    }
                                }
                            }
                        ))
                        .disabled(isAuthenticating)
                        .help("Encrypts clipboard history on disk using AES-256-GCM")
                    } else {
                        ProLockedRow(label: "Encrypt history at rest", feature: .encryption, licenseService: licenseService)
                            .help("Encrypts clipboard history on disk using AES-256-GCM — requires Pro")
                    }
                    CompactDivider()
                    ExcludedAppsInline(
                        excludedApps: Binding(
                            get: { settings.excludedApps },
                            set: { settings.excludedApps = $0 }
                        ),
                        requireAuthForRemoval: true,
                        authenticate: { reason, onSuccess in
                            Task { @MainActor in
                                if await authenticateForSecurityChange(reason: reason) {
                                    onSuccess()
                                }
                            }
                        }
                    )
                }

                #if !APP_STORE
                    CompactSection("Software Updates") {
                        SaneSparkleRow(
                            automaticallyChecks: Binding(
                                get: { autoCheckUpdates },
                                set: { newValue in
                                    autoCheckUpdates = newValue
                                    UpdateService.shared.automaticallyChecksForUpdates = newValue
                                }
                            ),
                            checkFrequency: Binding(
                                get: { updateCheckFrequency },
                                set: { newValue in
                                    updateCheckFrequency = newValue
                                    UpdateService.shared.updateCheckFrequency = newValue
                                }
                            ),
                            onCheckNow: { UpdateService.shared.checkForUpdates() }
                        )
                    }
                #endif

                CompactSection("History") {
                    CompactRow("Maximum Items") {
                        if isPro {
                            Picker("", selection: Binding(
                                get: { settings.maxHistorySize },
                                set: { settings.maxHistorySize = $0 }
                            )) {
                                Text("50").tag(50)
                                Text("100").tag(100)
                                Text("200").tag(200)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)
                        } else {
                            Button {
                                if let ls = licenseService {
                                    ProUpsellWindow.show(feature: ProFeature.unlimitedHistory, licenseService: ls)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("50")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("•")
                                        .foregroundStyle(.white.opacity(0.7))
                                    Text("100 / 200")
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(.teal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    CompactDivider()
                    CompactRow("Auto-delete After") {
                        Picker("", selection: Binding(
                            get: { settings.autoExpireHours },
                            set: { settings.autoExpireHours = $0 }
                        )) {
                            Text("Never").tag(0)
                            Text("1 hour").tag(1)
                            Text("24 hours").tag(24)
                            Text("7 days").tag(168)
                            Text("30 days").tag(720)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        .help("Pinned items are never deleted")
                    }
                    CompactDivider()
                    CompactRow("Storage") {
                        Text("~/Library/Application Support/SaneClip/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    CompactDivider()
                    CompactRow("Data") {
                        if isPro {
                            HStack(spacing: 8) {
                                Button("Export...") {
                                    exportHistory()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Import...") {
                                    importHistory()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            Button {
                                if let ls = licenseService {
                                    ProUpsellWindow.show(feature: ProFeature.exportImport, licenseService: ls)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10))
                                    Text("Export / Import")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.teal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                CompactSection("Capture Controls") {
                    CompactRow("Ignore Next Copy") {
                        Button("Ignore Once") {
                            ClipboardManager.shared?.ignoreNextCopy()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    CompactDivider()
                    CompactRow("Pause Capture") {
                        HStack(spacing: 6) {
                            Button("5m") { ClipboardManager.shared?.pauseCapture(minutes: 5) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("15m") { ClipboardManager.shared?.pauseCapture(minutes: 15) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("60m") { ClipboardManager.shared?.pauseCapture(minutes: 60) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("Resume") { ClipboardManager.shared?.resumeCapture() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    CompactDivider()
                    CompactRow("Max Text Size") {
                        Picker("", selection: Binding(
                            get: { settings.maxCaptureTextBytes },
                            set: { settings.maxCaptureTextBytes = $0 }
                        )) {
                            Text("64 KB").tag(64 * 1024)
                            Text("256 KB").tag(256 * 1024)
                            Text("512 KB").tag(512 * 1024)
                            Text("1 MB").tag(1024 * 1024)
                            Text("Unlimited").tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110)
                    }
                    CompactDivider()
                    CompactRow("Max Image Size") {
                        Picker("", selection: Binding(
                            get: { settings.maxCaptureImageBytes },
                            set: { settings.maxCaptureImageBytes = $0 }
                        )) {
                            Text("2 MB").tag(2 * 1024 * 1024)
                            Text("5 MB").tag(5 * 1024 * 1024)
                            Text("10 MB").tag(10 * 1024 * 1024)
                            Text("25 MB").tag(25 * 1024 * 1024)
                            Text("Unlimited").tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110)
                    }
                }

                ClipboardRulesSection(licenseService: licenseService)

                CompactSection("Backup & Restore") {
                    CompactRow("Settings") {
                        HStack(spacing: 8) {
                            Button("Export...") {
                                exportSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Import...") {
                                importSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            #if !APP_STORE
                autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
                updateCheckFrequency = UpdateService.shared.updateCheckFrequency
            #endif
        }
    }

    @MainActor
    private func authenticateForSecurityChange(reason: String) async -> Bool {
        isAuthenticating = true
        let context = LAContext()
        var error: NSError?

        // Use biometrics if available, otherwise fall back to device password
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        let success = await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                policy,
                localizedReason: reason
            ) { didSucceed, _ in
                continuation.resume(returning: didSucceed)
            }
        }

        isAuthenticating = false
        return success
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipboard-history.json"
        panel.title = "Export Clipboard History"

        presentSavePanel(panel) { url in
            if let data = ClipboardManager.exportHistoryFromDisk() {
                do {
                    try data.write(to: url)
                } catch {
                    print("Failed to export history: \(error)")
                }
            }
        }
    }

    private func importHistory() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import Clipboard History"
        panel.message = "Select a previously exported clipboard history file"

        presentOpenPanel(panel) { url in
            // Show merge/replace confirmation
            let alert = NSAlert()
            alert.messageText = "Import Clipboard History"
            alert.informativeText = "How would you like to import the history?"
            alert.addButton(withTitle: "Merge")
            alert.addButton(withTitle: "Replace All")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn: // Merge
                performImport(from: url, merge: true)
            case .alertSecondButtonReturn: // Replace
                performImport(from: url, merge: false)
            default:
                break
            }
        }
    }

    private func performImport(from url: URL, merge: Bool) {
        guard let manager = ClipboardManager.shared else { return }
        do {
            let count = try manager.importHistory(from: url, merge: merge)
            let alert = NSAlert()
            alert.messageText = "Import Successful"
            alert.informativeText = merge
                ? "Imported \(count) new items."
                : "Replaced history with \(count) items."
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "saneclip-settings.json"
        panel.title = "Export Settings"

        presentSavePanel(panel) { url in
            do {
                let data = try settings.exportSettings()
                try data.write(to: url)
                let alert = NSAlert()
                alert.messageText = "Settings Exported"
                alert.informativeText = "Your settings have been saved."
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import Settings"
        panel.message = "Select a previously exported settings file"

        presentOpenPanel(panel) { url in
            do {
                let data = try Data(contentsOf: url)
                try settings.importSettings(from: data)
                let alert = NSAlert()
                alert.messageText = "Settings Imported"
                alert.informativeText = "Your settings have been restored."
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}

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
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut("n", modifiers: .command)
                .focused($focusedKeyboardTarget, equals: .addButton)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 8) {
                ForEach(Self.presets) { preset in
                    presetButton(label: preset.label, bundleID: preset.bundleID)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Subtitle
            if excludedApps.isEmpty {
                HStack {
                    Text("Click \"Add App\" to exclude from clipboard history")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                HStack {
                    Text("Clips from these apps won't be saved:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
            HStack(spacing: 4) {
                Image(systemName: exists ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(exists ? .green : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .focused($focusedKeyboardTarget, equals: .preset(bundleID))
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

    var body: some View {
        HStack {
            Text(appName)
                .foregroundStyle(.white)

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(isHovering ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.clipBlue.opacity(0.16) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clipBlue.opacity(0.55) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var licenseService: LicenseService?
    private var isPro: Bool { licenseService?.isPro == true }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CompactSection("Main Shortcuts") {
                    CompactRow("Show Clipboard History") {
                        KeyboardShortcuts.Recorder(for: .showClipboardHistory)
                    }
                    CompactDivider()
                    CompactToggle(label: "Open history at mouse cursor", isOn: Binding(
                        get: { SettingsModel.shared.openHistoryAtCursor },
                        set: { SettingsModel.shared.openHistoryAtCursor = $0 }
                    ))
                    CompactDivider()
                    if isPro {
                        CompactRow("Paste as Plain Text") {
                            KeyboardShortcuts.Recorder(for: .pasteAsPlainText)
                        }
                    } else {
                        ProLockedRow(label: "Paste as Plain Text shortcut", feature: .plainTextPaste, licenseService: licenseService)
                    }
                    CompactDivider()
                    if isPro {
                        CompactRow("Paste from Stack") {
                            KeyboardShortcuts.Recorder(for: .pasteFromStack)
                        }
                    } else {
                        ProLockedRow(label: "Paste from Stack shortcut", feature: .pasteStack, licenseService: licenseService)
                    }
                    CompactDivider()
                    if isPro {
                        CompactRow("Smart Paste") {
                            KeyboardShortcuts.Recorder(for: .pasteSmartMode)
                        }
                    } else {
                        ProLockedRow(label: "Smart Paste shortcut", feature: .smartPaste, licenseService: licenseService)
                    }
                    CompactDivider()
                    CompactRow("Ignore Next Copy") {
                        KeyboardShortcuts.Recorder(for: .ignoreNextCopy)
                    }
                }

                CompactSection("Quick Paste (Items 1-9)") {
                    CompactRow("Paste Item 1") {
                        KeyboardShortcuts.Recorder(for: .pasteItem1)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 2") {
                        KeyboardShortcuts.Recorder(for: .pasteItem2)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 3") {
                        KeyboardShortcuts.Recorder(for: .pasteItem3)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 4") {
                        KeyboardShortcuts.Recorder(for: .pasteItem4)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 5") {
                        KeyboardShortcuts.Recorder(for: .pasteItem5)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 6") {
                        KeyboardShortcuts.Recorder(for: .pasteItem6)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 7") {
                        KeyboardShortcuts.Recorder(for: .pasteItem7)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 8") {
                        KeyboardShortcuts.Recorder(for: .pasteItem8)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 9") {
                        KeyboardShortcuts.Recorder(for: .pasteItem9)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    @State private var showLicenses = false
    @State private var showSupport = false
    @State private var showFeedback = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App identity
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)

            VStack(spacing: 8) {
                Text("SaneClip")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Version \(version)")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.92))
                }
            }

            // Trust info
            HStack(spacing: 0) {
                Text("Made with ❤️ in 🇺🇸")
                    .fontWeight(.medium)
                Text(" · ")
                Text("100% On-Device")
                Text(" · ")
                Text("No Analytics")
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.92))
            .padding(.top, 4)

            // Action grid (two clean rows)
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com/sane-apps/SaneClip")!) {
                        Label("GitHub", systemImage: "link")
                    }

                    Button {
                        showLicenses = true
                    } label: {
                        Label("Licenses", systemImage: "doc.text")
                    }

                    Button {
                        showSupport = true
                    } label: {
                        Label {
                            Text("Support")
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        showFeedback = true
                    } label: {
                        Label("Report Issue", systemImage: "ladybug")
                    }

                    Link(destination: URL(string: "https://github.com/sane-apps/SaneClip/issues/new?template=bug_report.md")!) {
                        Label("View Issues", systemImage: "arrow.up.right.square")
                    }

                    Link(destination: URL(string: "mailto:hi@saneapps.com")!) {
                        Label("Questions", systemImage: "envelope")
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.top, 12)

            #if !APP_STORE
                // Check for Updates
                Button {
                    checkForUpdates()
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            #endif

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showLicenses) {
            licensesSheet
        }
        .sheet(isPresented: $showSupport) {
            supportSheet
        }
        .sheet(isPresented: $showFeedback) {
            SaneFeedbackView(diagnosticsService: .shared)
        }
    }

    #if !APP_STORE
        private func checkForUpdates() {
            UpdateService.shared.checkForUpdates()
        }
    #endif

    // MARK: - Licenses Sheet

    private var licensesSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Third-Party Licenses")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showLicenses = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            let url = URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!
                            Link("KeyboardShortcuts", destination: url)
                                .font(.headline)

                            Text("""
                            MIT License (third-party dependency)

                            Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)

                            Permission is hereby granted, free of charge, to any person obtaining a copy \
                            of this software and associated documentation files (the "Software"), to deal \
                            in the Software without restriction, including without limitation the rights \
                            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                            copies of the Software, and to permit persons to whom the Software is \
                            furnished to do so, subject to the following conditions:

                            The above copyright notice and this permission notice shall be included in all \
                            copies or substantial portions of the Software.

                            THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
                            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
                            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
                            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
                            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
                            SOFTWARE.
                            """)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Link("Sparkle", destination: URL(string: "https://sparkle-project.org")!)
                                .font(.headline)

                            Text("""
                            Copyright (c) 2006-2013 Andy Matuschak.
                            Copyright (c) 2009-2013 Elgato Systems GmbH.
                            Copyright (c) 2011-2014 Kornel Lesiński.
                            Copyright (c) 2015-2017 Mayur Pawashe.
                            Copyright (c) 2014 C.W. Betts.
                            Copyright (c) 2014 Petroules Corporation.
                            Copyright (c) 2014 Big Nerd Ranch.
                            All rights reserved.

                            Permission is hereby granted, free of charge, to any person obtaining a copy of
                            this software and associated documentation files (the "Software"), to deal in
                            the Software without restriction, including without limitation the rights to
                            use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
                            of the Software, and to permit persons to whom the Software is furnished to do
                            so, subject to the following conditions:

                            The above copyright notice and this permission notice shall be included in all
                            copies or substantial portions of the Software.

                            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
                            FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
                            COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
                            IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
                            CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
                            """)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - Support Sheet

    private var supportSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Support SaneClip")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showSupport = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Quote
                    VStack(spacing: 4) {
                        Text("\"The worker is worthy of his wages.\"")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .italic()
                        Text("— 1 Timothy 5:18")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Personal message
                    Text("""
                    I need your help to keep SaneClip alive. \
                    Your support — whether one-time or monthly — makes this possible. Thank you.
                    """)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                    Text("— Mr. Sane")
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)

                    Divider()
                        .padding(.horizontal, 40)

                    // GitHub Sponsors
                    Link(destination: URL(string: "https://github.com/sponsors/sane-apps")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("Sponsor on GitHub")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.pink.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Crypto addresses
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or send crypto:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                        CryptoAddressRow(label: "BTC", address: "3Go9nJu3dj2qaa4EAYXrTsTf5AnhcrPQke")
                        CryptoAddressRow(label: "SOL", address: "FBvU83GUmwEYk3HMwZh3GBorGvrVVWSPb8VLCKeLiWZZ")
                        CryptoAddressRow(label: "ZEC", address: "t1PaQ7LSoRDVvXLaQTWmy5tKUAiKxuE9hBN")
                    }
                    .padding()
                    .background(.fill.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
        }
        .frame(width: 420, height: 360)
    }
}

// MARK: - Crypto Address Row

private struct CryptoAddressRow: View {
    let label: String
    let address: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.blue)
                .frame(width: 36, alignment: .leading)

            Text(address)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(address, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(copied ? .green : .secondary)
        }
    }
}

// MARK: - Settings Gradient Background

struct SettingsGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                // Dark mode: beautiful glass effect
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

                // Subtle navy-teal tint
                LinearGradient(
                    colors: [
                        Color.clipBlue.opacity(0.08),
                        Color.teal.opacity(0.05),
                        Color.clipBlue.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: soft, warm gradient - not stark white
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.92, green: 0.95, blue: 0.99),
                        Color(red: 0.94, green: 0.96, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Compact Components

struct CompactSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Color.clipBlue.opacity(0.15), lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.15) : .clipBlue.opacity(0.08),
                radius: colorScheme == .dark ? 8 : 6, x: 0, y: 3
            )
            .padding(.horizontal, 2)
        }
    }
}

struct CompactRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct CompactToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct CompactDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 12)
    }
}

// MARK: - Glass Group Box Style

struct GlassGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            configuration.content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? .thickMaterial : .regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: 4, y: 2)
    }
}

// MARK: - Settings Window Controller

@MainActor
enum SettingsWindowController {
    enum PendingAction: Equatable {
        case excludedAppPicker
    }

    private static var window: NSWindow?
    private static var pendingAction: PendingAction?
    static var licenseService: LicenseService?
    static var presentedWindow: NSWindow? {
        guard let window, window.isVisible else { return nil }
        return window
    }

    static func open(tab: SettingsView.SettingsTab? = nil) {
        if let existingWindow = window, existingWindow.isVisible {
            if let tab {
                existingWindow.contentViewController = makeHostingController(initialTab: tab)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(contentViewController: makeHostingController(initialTab: tab))
        newWindow.title = "SaneClip Settings"
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.styleMask = [.titled, .closable, .resizable]
        newWindow.setContentSize(NSSize(width: 700, height: 450))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Standard window - glass effect handled in SwiftUI view
        newWindow.hasShadow = true

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        window?.performClose(nil)
    }

    static func schedulePendingAction(_ action: PendingAction) {
        pendingAction = action
    }

    static func consumePendingAction(_ action: PendingAction) -> Bool {
        guard pendingAction == action else { return false }
        pendingAction = nil
        return true
    }

    private static func makeHostingController(initialTab: SettingsView.SettingsTab?) -> NSHostingController<AnyView> {
        let settingsView = AnyView(
            SettingsView(licenseService: licenseService, initialTab: initialTab)
                .preferredColorScheme(.dark)
        )
        return NSHostingController(rootView: settingsView)
    }
}

// MARK: - Clipboard Rules Section

struct ClipboardRulesSection: View {
    var licenseService: LicenseService?
    @State private var rules = ClipboardRulesManager.shared

    private var isPro: Bool { licenseService?.isPro == true }

    var body: some View {
        CompactSection("Clipboard Rules") {
            if !isPro {
                ProLockedSectionBanner(feature: .clipboardRules, licenseService: licenseService)
            }
            CompactToggle(
                label: "Strip URL tracking parameters",
                isOn: Binding(
                    get: { rules.stripTrackingParams },
                    set: { rules.stripTrackingParams = $0 }
                )
            )
            .help("Remove utm_*, fbclid, and other tracking params from URLs — requires Pro")
            .disabled(!isPro)

            CompactDivider()

            CompactToggle(
                label: "Auto-trim whitespace",
                isOn: Binding(
                    get: { rules.autoTrimWhitespace },
                    set: { rules.autoTrimWhitespace = $0 }
                )
            )
            .help("Remove leading/trailing spaces from copied text — requires Pro")
            .disabled(!isPro)

            CompactDivider()

            CompactToggle(
                label: "Normalize line endings",
                isOn: Binding(
                    get: { rules.normalizeLineEndings },
                    set: { rules.normalizeLineEndings = $0 }
                )
            )
            .help("Convert Windows (CRLF) to Unix (LF) line endings — requires Pro")
            .disabled(!isPro)

            CompactDivider()

            CompactToggle(
                label: "Remove duplicate spaces",
                isOn: Binding(
                    get: { rules.removeDuplicateSpaces },
                    set: { rules.removeDuplicateSpaces = $0 }
                )
            )
            .help("Collapse multiple consecutive spaces into one — requires Pro")
            .disabled(!isPro)

            CompactDivider()

            CompactToggle(
                label: "Lowercase URL hosts",
                isOn: Binding(
                    get: { rules.lowercaseURLs },
                    set: { rules.lowercaseURLs = $0 }
                )
            )
            .help("Convert URL hostnames to lowercase — requires Pro")
            .disabled(!isPro)
        }
    }
}

// MARK: - Pro Lock Helpers

/// Inline row showing a lock badge with a "Pro" label — tapping shows the upsell.
private struct ProLockedRow: View {
    let label: String
    let feature: ProFeature
    var licenseService: LicenseService?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button {
                if let ls = licenseService {
                    ProUpsellWindow.show(feature: feature, licenseService: ls)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Pro")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.teal)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Banner shown at the top of a Pro-gated section to explain the requirement.
private struct ProLockedSectionBanner: View {
    let feature: ProFeature
    var licenseService: LicenseService?

    var body: some View {
        Button {
            if let ls = licenseService {
                ProUpsellWindow.show(feature: feature, licenseService: ls)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.teal)
                Text("These settings require SaneClip Pro")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("Upgrade")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.teal)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }
}
// swiftlint:enable file_length
