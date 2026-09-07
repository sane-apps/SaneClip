import AppKit
import SaneUI
import SwiftUI

struct ClipboardSettingsView: View {
    var licenseService: LicenseService?
    @State var settings = SettingsModel.shared
    private var isPro: Bool {
        licenseService?.isPro == true
    }

    @State private var appPresetBundleID = ""
    @State private var appPresetMode: PasteMode = .standard
    @State private var screenCapturePermissionGranted = ScreenCapturePermissionService.isGranted()

    var body: some View {
        SaneSettingsPage {
            Text(String(localized: "Clipboard"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            CompactSection(String(localized: "Pasting")) {
                if isPro {
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

                } else {
                    ProLockedRow(label: SaneClipSettingsCopy.defaultPasteModeLockedLabel, feature: .smartPaste, licenseService: licenseService)
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
            }

            CompactSection(String(localized: "History Window")) {
                if isPro {
                    CompactToggle(label: "Open history as a resizable floating window", isOn: Binding(
                        get: { settings.useFloatingHistoryWindow },
                        set: { settings.useFloatingHistoryWindow = $0 }
                    ))
                } else {
                    ProLockedRow(
                        label: "Open history as a resizable floating window",
                        feature: .floatingHistoryWindow,
                        licenseService: licenseService
                    )
                }
            }

            CompactSection(String(localized: "Paste Stack")) {
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

                } else {
                    ProLockedRow(label: SaneClipSettingsCopy.pasteStackOrderLockedLabel, feature: .pasteStack, licenseService: licenseService)
                }
            }

            CompactSection(String(localized: "Per-App Paste Mode")) {
                if isPro {
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
                    .padding(12)
                } else {
                    ProLockedRow(label: SaneClipSettingsCopy.defaultPasteModeLockedLabel, feature: .smartPaste, licenseService: licenseService)
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
            }

            CompactSection(String(localized: "Capture Limits")) {
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

            CompactSection(String(localized: "Screenshots & Text Recognition")) {
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
                            .foregroundStyle(.white)

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
        }
        .onAppear { refreshPermissionState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionState()
        }
    }

    func refreshPermissionState() {
        screenCapturePermissionGranted = ScreenCapturePermissionService.isGranted()
    }
}
