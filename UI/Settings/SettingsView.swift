// swiftlint:disable file_length
import KeyboardShortcuts
import LocalAuthentication
import SaneUI
import SwiftUI
import os.log

private let settingsLogger = Logger(subsystem: "com.saneclip.app", category: "Settings")
let clipReadableSecondary = Color.white.opacity(0.88)
let clipReadableMuted = Color.white.opacity(0.78)
let clipReadableMonospace = Color.white.opacity(0.92)

typealias ClipActionButtonStyle = SaneUI.SaneActionButtonStyle

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

    enum SettingsTab: String, SaneSettingsTab {
        case general = "General"
        case shortcuts = "Shortcuts"
        #if ENABLE_SYNC
            case sync = "Sync"
        #endif
        case snippets = "Snippets"
        case storage = "Storage"
        case license = "License"
        case about = "About"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: SaneSettingsStrings.generalTabTitle
            case .shortcuts: SaneSettingsStrings.shortcutsTabTitle
            #if ENABLE_SYNC
                case .sync: SaneSettingsStrings.syncTabTitle
            #endif
            case .snippets: SaneSettingsStrings.snippetsTabTitle
            case .storage: SaneSettingsStrings.storageTabTitle
            case .license: SaneSettingsStrings.licenseTabTitle
            case .about: SaneSettingsStrings.aboutTabTitle
            }
        }

        var icon: String {
            switch self {
            case .general: "gear"
            case .shortcuts: "keyboard"
            #if ENABLE_SYNC
                case .sync: "arrow.triangle.2.circlepath.icloud"
            #endif
            case .snippets: "text.quote"
            case .storage: "chart.pie"
            case .license: "key"
            case .about: "info.circle"
            }
        }

        var iconColor: Color {
            switch self {
            case .general: SaneSettingsIconSemantic.general.color
            case .shortcuts: SaneSettingsIconSemantic.shortcuts.color
            #if ENABLE_SYNC
                case .sync: SaneSettingsIconSemantic.sync.color
            #endif
            case .snippets: SaneSettingsIconSemantic.content.color
            case .storage: SaneSettingsIconSemantic.storage.color
            case .license: SaneSettingsIconSemantic.license.color
            case .about: SaneSettingsIconSemantic.about.color
            }
        }
    }

    init(licenseService: LicenseService?, initialTab: SettingsTab? = .general) {
        self.licenseService = licenseService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        SaneSettingsContainer(defaultTab: .general, selection: $selectedTab, windowSizing: .embedded) { tab in
            switch tab {
            case .general:
                GeneralSettingsView(licenseService: licenseService)
            case .shortcuts:
                ShortcutsSettingsView(licenseService: licenseService)
            #if ENABLE_SYNC
            case .sync:
                SyncSettingsView()
            #endif
            case .snippets:
                SnippetsSettingsView(licenseService: licenseService)
                    .padding(20)
            case .storage:
                StorageStatsView()
                    .padding(20)
            case .license:
                Group {
                    if let licenseService {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                LicenseSettingsView(licenseService: licenseService, style: .panel)
                                    .frame(maxWidth: 420, alignment: .leading)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(20)
                        }
                    } else {
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .about:
                SaneAboutView(
                    appName: "SaneClip",
                    githubRepo: "SaneClip",
                    diagnosticsService: .shared,
                    licenses: saneClipAboutLicenses(licenseService: licenseService)
                )
            }
        }
        .frame(minWidth: 760, idealWidth: 760, minHeight: 500, idealHeight: 500)
        .background(settingsKeyboardShortcuts)
        .onExitCommand {
            SettingsWindowController.close()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsTabShortcutRequested)) { notification in
            guard let tab = notification.object as? SettingsTab else { return }
            selectedTab = tab
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
private func saneClipAboutLicenses(licenseService: LicenseService?) -> [SaneAboutView.LicenseEntry] {
    var entries = [
        SaneAboutView.LicenseEntry(
            name: "KeyboardShortcuts",
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            text: """
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

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
            SOFTWARE.
            """
        )
    ]

    if licenseService?.distributionChannel.supportsInAppUpdates == true {
        entries.append(
            SaneAboutView.LicenseEntry(
                name: "Sparkle",
                url: "https://sparkle-project.org",
                text: """
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
                """
            )
        )
    }

    return entries
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
    #if !APP_STORE && !SETAPP
        @State private var autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
        @State private var updateCheckFrequency = UpdateService.shared.updateCheckFrequency
    #else
        @State private var autoCheckUpdates = false
    #endif
    @State private var isAuthenticating = false

    private var isPro: Bool { licenseService?.isPro == true }
    private var historySizeChoices: [Int] {
        let currentChoice = SettingsModel.normalizedMaxHistorySize(settings.maxHistorySize)
        let allChoices = Set(SettingsModel.proHistorySizeChoices + [currentChoice])
        return allChoices.sorted { lhs, rhs in
            if SettingsModel.isUnlimitedHistorySize(lhs) {
                return false
            }
            if SettingsModel.isUnlimitedHistorySize(rhs) {
                return true
            }
            return lhs < rhs
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CompactSection(SaneClipSettingsCopy.startupSectionTitle) {
                    SaneLoginItemToggle()
                    CompactDivider()
                    SaneDockIconToggle(showDockIcon: Binding(
                        get: { settings.showInDock },
                        set: { settings.showInDock = $0 }
                    ))
                }

                SaneLanguageSettingsRow()

                CompactSection(SaneClipSettingsCopy.appearanceSectionTitle) {
                    CompactRow(SaneClipSettingsCopy.menuBarIconLabel) {
                        HStack(spacing: 8) {
                            Image(nsImage: popupSymbolImage(settings.menuBarIcon))

                            Picker("", selection: Binding(
                                get: { settings.menuBarIcon },
                                set: { settings.menuBarIcon = $0 }
                            )) {
                                Text(SaneClipSettingsCopy.menuBarIconListTitle)
                                    .tag("list.clipboard.fill")
                                Text(SaneClipSettingsCopy.menuBarIconMinimalTitle)
                                    .tag("doc.plaintext")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 104)
                        }
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.pasteSoundLabel) {
                        HStack(spacing: 8) {
                            Picker("", selection: Binding(
                                get: { settings.pasteSound },
                                set: { settings.pasteSound = $0 }
                            )) {
                                ForEach(PasteSound.allCases, id: \.self) { sound in
                                    Text(SaneClipSettingsCopy.pasteSoundDisplayName(sound)).tag(sound)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)

                            Button {
                                settings.pasteSound.play()
                            } label: {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)
                            .disabled(settings.pasteSound == .off)
                            .help(SaneClipSettingsCopy.pasteSoundPreviewHelp)
                        }
                    }
                    CompactDivider()
                    if isPro {
                        CompactToggle(label: SaneClipSettingsCopy.pasteStackNewestFirstLabel, isOn: Binding(
                            get: { settings.pasteStackReversed },
                            set: { settings.pasteStackReversed = $0 }
                        ))
                        CompactDivider()
                        CompactToggle(label: SaneClipSettingsCopy.keepStackPanelOpenLabel, isOn: Binding(
                            get: { settings.keepPasteStackOpenBetweenPastes },
                            set: { settings.keepPasteStackOpenBetweenPastes = $0 }
                        ))
                        CompactDivider()
                        CompactToggle(label: SaneClipSettingsCopy.autoCloseStackPanelLabel, isOn: Binding(
                            get: { settings.autoClosePasteStackWhenEmpty },
                            set: { settings.autoClosePasteStackWhenEmpty = $0 }
                        ))
                        CompactDivider()
                        CompactToggle(label: SaneClipSettingsCopy.collapseDuplicateStackItemsLabel, isOn: Binding(
                            get: { settings.collapseDuplicatePasteStackItems },
                            set: { settings.collapseDuplicatePasteStackItems = $0 }
                        ))
                        CompactDivider()
                        CompactRow(SaneClipSettingsCopy.defaultPasteModeLabel) {
                            Picker("", selection: Binding(
                                get: { SettingsModel.shared.defaultPasteMode },
                                set: { SettingsModel.shared.defaultPasteMode = $0 }
                            )) {
                                ForEach(PasteMode.allCases, id: \.self) { mode in
                                    Text(SaneClipSettingsCopy.pasteModeDisplayName(mode)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                        }
                        HStack {
                            Spacer()
                            Text(SaneClipSettingsCopy.pasteModeDescription(SettingsModel.shared.defaultPasteMode))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)

                        CompactRow(SaneClipSettingsCopy.perAppPasteModeLabel) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    TextField(SaneClipSettingsCopy.appPresetPlaceholder, text: $appPresetBundleID)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 190)
                                    Picker("", selection: $appPresetMode) {
                                        ForEach(PasteMode.allCases, id: \.self) { mode in
                                            Text(SaneClipSettingsCopy.pasteModeDisplayName(mode)).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 110)
                                    Button(SaneClipSettingsCopy.saveButtonTitle) {
                                        let key = appPresetBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !key.isEmpty else { return }
                                        settings.setPasteMode(appPresetMode, for: key)
                                        appPresetBundleID = ""
                                    }
                                    .buttonStyle(ClipActionButtonStyle())
                                    .controlSize(.small)
                                }

                                if settings.perAppPasteModes.isEmpty {
                                    Text(SaneClipSettingsCopy.noOverridesConfigured)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(clipReadableSecondary)
                                } else {
                                    ForEach(settings.perAppPasteModes.keys.sorted(), id: \.self) { bundleID in
                                        HStack(spacing: 8) {
                                            Text(bundleID)
                                                .font(.system(size: 13, design: .monospaced))
                                                .lineLimit(1)
                                            Spacer(minLength: 8)
                                            Text(SaneClipSettingsCopy.pasteModeDisplayName(settings.pasteMode(for: bundleID) ?? .standard))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(clipReadableSecondary)
                                            Button(SaneClipSettingsCopy.removeButtonTitle) {
                                                settings.setPasteMode(nil, for: bundleID)
                                            }
                                            .buttonStyle(ClipActionButtonStyle())
                                            .controlSize(.small)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    } else {
                        ProLockedRow(label: SaneClipSettingsCopy.pasteStackOrderLockedLabel, feature: .pasteStack, licenseService: licenseService)
                        CompactDivider()
                        ProLockedRow(label: SaneClipSettingsCopy.defaultPasteModeLockedLabel, feature: .smartPaste, licenseService: licenseService)
                    }
                }

                CompactSection(SaneClipSettingsCopy.securitySectionTitle) {
                    CompactToggle(label: SaneClipSettingsCopy.detectPasswordsLabel, isOn: Binding(
                        get: { settings.protectPasswords },
                        set: { newValue in
                            if newValue {
                                // Turning ON - no auth needed
                                settings.protectPasswords = true
                            } else {
                                // Turning OFF - always requires auth
                                let reason = SaneClipSettingsCopy.authenticatePasswordManagerMessage
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
                        CompactToggle(label: SaneClipSettingsCopy.touchIDLabel, isOn: Binding(
                            get: { settings.requireTouchID },
                            set: { newValue in
                                if newValue {
                                    // Turning ON - no auth needed
                                    settings.requireTouchID = true
                                } else {
                                    // Turning OFF - always requires auth
                                    Task { @MainActor in
                                        if await authenticateForSecurityChange(reason: String(localized: "saneclip.settings.security.authenticate_disable_touch_id", defaultValue: "Authenticate to disable Touch ID protection")) {
                                            settings.requireTouchID = false
                                        }
                                    }
                                }
                            }
                        ))
                        .disabled(isAuthenticating)
                    } else {
                        ProLockedRow(label: SaneClipSettingsCopy.touchIDLabel, feature: .historyLock, licenseService: licenseService)
                    }
                    CompactDivider()
                    if isPro {
                        CompactToggle(label: SaneClipSettingsCopy.encryptHistoryLabel, isOn: Binding(
                            get: { settings.encryptHistory },
                            set: { newValue in
                                if newValue {
                                    // Turning ON encryption - no auth needed
                                    settings.encryptHistory = true
                                } else {
                                    // Turning OFF encryption - requires auth
                                    Task { @MainActor in
                                        if await authenticateForSecurityChange(reason: String(localized: "saneclip.settings.security.authenticate_disable_history_encryption", defaultValue: "Authenticate to disable history encryption")) {
                                            settings.encryptHistory = false
                                        }
                                    }
                                }
                            }
                        ))
                        .disabled(isAuthenticating)
                        .help(SaneClipSettingsCopy.encryptHistoryHelp)
                    } else {
                        ProLockedRow(label: SaneClipSettingsCopy.encryptHistoryLabel, feature: .encryption, licenseService: licenseService)
                            .help(String(localized: "saneclip.settings.security.encrypt_history_pro_help", defaultValue: "Encrypts clipboard history on disk using AES-256-GCM — requires Pro"))
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

                #if !APP_STORE && !SETAPP
                    CompactSection(SaneClipSettingsCopy.softwareUpdatesSectionTitle) {
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
                            labels: .init(
                                automaticCheckLabel: SaneClipSettingsCopy.updateAutomaticallyLabel,
                                automaticCheckHelp: SaneClipSettingsCopy.updateAutomaticallyHelp,
                                checkFrequencyLabel: SaneClipSettingsCopy.updateFrequencyLabel,
                                checkFrequencyHelp: SaneClipSettingsCopy.updateFrequencyHelp,
                                actionsLabel: SaneClipSettingsCopy.updatesActionsLabel,
                                checkingLabel: SaneClipSettingsCopy.checkingButtonTitle,
                                checkNowLabel: SaneClipSettingsCopy.checkNowButtonTitle,
                                checkNowHelp: SaneClipSettingsCopy.checkNowHelp,
                                dailyTitle: String(localized: "saneclip.settings.updates.daily", defaultValue: "Daily"),
                                weeklyTitle: String(localized: "saneclip.settings.updates.weekly", defaultValue: "Weekly")
                            ),
                            onCheckNow: { UpdateService.shared.checkForUpdates() }
                        )
                    }
                #endif

                    CompactSection(SaneClipSettingsCopy.historySectionTitle) {
                        CompactRow(SaneClipSettingsCopy.maximumItemsLabel) {
                            if isPro {
                                Picker("", selection: Binding(
                                    get: { settings.maxHistorySize },
                                    set: { settings.maxHistorySize = SettingsModel.normalizedMaxHistorySize($0) }
                                )) {
                                    ForEach(historySizeChoices, id: \.self) { choice in
                                        Text(SettingsModel.historySizeLabel(choice)).tag(choice)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                                .help("Pro keeps as much history as you configure, including unlimited.")
                            } else {
                                Button {
                                    if let ls = licenseService {
                                        ProUpsellWindow.show(feature: ProFeature.unlimitedHistory, licenseService: ls)
                                    }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("50")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("•")
                                        .foregroundStyle(.white.opacity(0.7))
                                    Text("100 / 500 / Unlimited")
                                        .foregroundStyle(.white)
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.clipBlue.opacity(0.95))
                                }
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)
                        }
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.autoDeleteAfterLabel) {
                        Picker("", selection: Binding(
                            get: { settings.autoExpireHours },
                            set: { settings.autoExpireHours = $0 }
                        )) {
                            Text(String(localized: "saneclip.settings.history.never", defaultValue: "Never")).tag(0)
                            Text(String(localized: "saneclip.settings.history.1_hour", defaultValue: "1 hour")).tag(1)
                            Text(String(localized: "saneclip.settings.history.24_hours", defaultValue: "24 hours")).tag(24)
                            Text(String(localized: "saneclip.settings.history.7_days", defaultValue: "7 days")).tag(168)
                            Text(String(localized: "saneclip.settings.history.30_days", defaultValue: "30 days")).tag(720)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        .help(SaneClipSettingsCopy.pinnedItemsHelp)
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.storageLabel) {
                        Text("~/Library/Application Support/SaneClip/")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(clipReadableSecondary)
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.dataLabel) {
                        if isPro {
                            HStack(spacing: 8) {
                                Button(SaneClipSettingsCopy.exportButtonTitle) {
                                    exportHistory()
                                }
                                .buttonStyle(ClipActionButtonStyle())
                                .controlSize(.small)

                                Button(SaneClipSettingsCopy.importButtonTitle) {
                                    importHistory()
                                }
                                .buttonStyle(ClipActionButtonStyle())
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
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(SaneClipSettingsCopy.exportImportLabel)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.teal)
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)
                        }
                    }
                }

                CompactSection(SaneClipSettingsCopy.captureControlsSectionTitle) {
                    CompactRow(SaneClipSettingsCopy.ignoreNextCopyLabel) {
                        Button(SaneClipSettingsCopy.ignoreOnceButtonTitle) {
                            ClipboardManager.shared?.ignoreNextCopy()
                        }
                        .buttonStyle(ClipActionButtonStyle())
                        .controlSize(.small)
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.pauseCaptureLabel) {
                        HStack(spacing: 6) {
                            Button(SaneClipSettingsCopy.pause5mTitle) { ClipboardManager.shared?.pauseCapture(minutes: 5) }
                                .buttonStyle(ClipActionButtonStyle())
                                .controlSize(.small)
                            Button(SaneClipSettingsCopy.pause15mTitle) { ClipboardManager.shared?.pauseCapture(minutes: 15) }
                                .buttonStyle(ClipActionButtonStyle())
                                .controlSize(.small)
                            Button(SaneClipSettingsCopy.pause60mTitle) { ClipboardManager.shared?.pauseCapture(minutes: 60) }
                                .buttonStyle(ClipActionButtonStyle())
                                .controlSize(.small)
                            Button(SaneClipSettingsCopy.resumeTitle) { ClipboardManager.shared?.resumeCapture() }
                                .buttonStyle(ClipActionButtonStyle())
                                .controlSize(.small)
                        }
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.textSizeLabel) {
                        Picker("", selection: Binding(
                            get: { settings.maxCaptureTextBytes },
                            set: { settings.maxCaptureTextBytes = $0 }
                        )) {
                            Text(String(localized: "saneclip.settings.history.text_64_kb", defaultValue: "64 KB")).tag(64 * 1024)
                            Text(String(localized: "saneclip.settings.history.text_256_kb", defaultValue: "256 KB")).tag(256 * 1024)
                            Text(String(localized: "saneclip.settings.history.text_512_kb", defaultValue: "512 KB")).tag(512 * 1024)
                            Text(String(localized: "saneclip.settings.history.text_1_mb", defaultValue: "1 MB")).tag(1024 * 1024)
                            Text(String(localized: "saneclip.settings.history.text_unlimited", defaultValue: "Unlimited")).tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110)
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.imageSizeLabel) {
                        Picker("", selection: Binding(
                            get: { settings.maxCaptureImageBytes },
                            set: { settings.maxCaptureImageBytes = $0 }
                        )) {
                            Text(String(localized: "saneclip.settings.history.image_2_mb", defaultValue: "2 MB")).tag(2 * 1024 * 1024)
                            Text(String(localized: "saneclip.settings.history.image_5_mb", defaultValue: "5 MB")).tag(5 * 1024 * 1024)
                            Text(String(localized: "saneclip.settings.history.image_10_mb", defaultValue: "10 MB")).tag(10 * 1024 * 1024)
                            Text(String(localized: "saneclip.settings.history.image_25_mb", defaultValue: "25 MB")).tag(25 * 1024 * 1024)
                            Text(String(localized: "saneclip.settings.history.text_unlimited", defaultValue: "Unlimited")).tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110)
                    }
                }

                ClipboardRulesSection(licenseService: licenseService)

                CompactSection(SaneClipSettingsCopy.backupRestoreSectionTitle) {
                    CompactRow(SaneClipSettingsCopy.settingsLabel) {
                        HStack(spacing: 8) {
                            Button(SaneClipSettingsCopy.exportButtonTitle) {
                                exportSettings()
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)

                            Button(SaneClipSettingsCopy.importButtonTitle) {
                                importSettings()
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            #if !APP_STORE && !SETAPP
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

    private func popupSymbolImage(_ systemImage: String) -> NSImage {
        let weightConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .white)
        let resolvedConfig = weightConfig.applying(colorConfig)

        guard let symbol = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)?
            .withSymbolConfiguration(resolvedConfig)
        else {
            return NSImage()
        }

        symbol.isTemplate = false
        return symbol
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
        settingsLogger.info("Opening settings window with license service present=\(licenseService != nil) isPro=\(licenseService?.isPro == true)")
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
        newWindow.contentMinSize = NSSize(width: 760, height: 500)
        newWindow.setContentSize(NSSize(width: 760, height: 500))
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
                        .font(.system(size: 12, weight: .semibold))
                    Text("Pro")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.teal)
            }
            .buttonStyle(ClipActionButtonStyle())
            .controlSize(.small)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.teal)
                Text("These settings require SaneClip Pro")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("Upgrade — \(licenseService?.displayPriceLabel ?? "$14.99")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.teal)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(ClipActionButtonStyle())
        .controlSize(.small)
    }
}
// swiftlint:enable file_length
