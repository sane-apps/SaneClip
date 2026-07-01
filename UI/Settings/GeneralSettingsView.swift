import AppKit
import KeyboardShortcuts
import LocalAuthentication
import os.log
import SaneUI
import SwiftUI

// MARK: - General Settings

struct GeneralSettingsView: View {
    var licenseService: LicenseService?
    @State var settings = SettingsModel.shared
    @State var screenCapturePermissionGranted = ScreenCapturePermissionService.isGranted()
    @State private var appPresetBundleID = ""
    @State private var appPresetMode: PasteMode = .standard
    #if !APP_STORE && !SETAPP
        @State private var autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
        @State private var updateCheckFrequency = UpdateService.shared.updateCheckFrequency
    #else
        @State private var autoCheckUpdates = false
    #endif
    @State var isAuthenticating = false

    private var isPro: Bool {
        licenseService?.isPro == true
    }

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
                    CompactToggle(label: SaneClipSettingsCopy.showMenuBarIconLabel, isOn: Binding(
                        get: { settings.showMenuBarIcon },
                        set: { settings.showMenuBarIcon = $0 }
                    ))
                    if settings.showMenuBarIcon {
                        CompactDivider()
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
                    }
                    CompactDivider()
                    CompactToggle(label: "Open history as a resizable floating window", isOn: Binding(
                        get: { settings.useFloatingHistoryWindow },
                        set: { settings.useFloatingHistoryWindow = $0 }
                    ))
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
                                        .foregroundStyle(.white)
                                    Text("100 / 500 / Unlimited")
                                        .foregroundStyle(.white)
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.teal)
                                    Text("Pro")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.teal)
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
                                    Text("Pro")
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
                    CompactDivider()
                    if isPro {
                        CompactToggle(label: SaneClipSettingsCopy.autoOCRScreenshotsLabel, isOn: Binding(
                            get: { settings.autoOCRCapturedScreenshots },
                            set: { settings.autoOCRCapturedScreenshots = $0 }
                        ))
                    } else {
                        ProLockedRow(label: SaneClipSettingsCopy.autoOCRScreenshotsLabel, feature: .ocrCapture, licenseService: licenseService)
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.screenRecordingPermissionLabel) {
                        HStack(spacing: 8) {
                            Text(screenCapturePermissionGranted
                                ? SaneClipSettingsCopy.screenRecordingGrantedStatus
                                : SaneClipSettingsCopy.screenRecordingMissingStatus)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(screenCapturePermissionGranted ? .green : .white)

                            Button(SaneClipSettingsCopy.openScreenRecordingSettingsButtonTitle) {
                                ScreenCapturePermissionService.openSettings()
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)
                        }
                    }
                    CompactDivider()
                    if isPro {
                        CompactRow(SaneClipSettingsCopy.ocrLanguageLabel) {
                            Picker("", selection: Binding(
                                get: { settings.captureOCRLanguage },
                                set: { settings.captureOCRLanguage = $0 }
                            )) {
                                ForEach(CaptureOCRLanguage.allCases, id: \.self) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 130)
                        }
                    } else {
                        ProLockedRow(label: SaneClipSettingsCopy.ocrLanguageLabel, feature: .ocrCapture, licenseService: licenseService)
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
            refreshPermissionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionState()
        }
    }
}
