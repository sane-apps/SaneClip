import AppKit
import LocalAuthentication
import SaneUI
import SwiftUI

struct PrivacySettingsView: View {
    var licenseService: LicenseService?
    @State var settings = SettingsModel.shared
    private var isPro: Bool {
        licenseService?.isPro == true
    }

    @State var isAuthenticating = false

    var body: some View {
        SaneSettingsPage {
            Text(String(localized: "Privacy"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
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
            }

            CompactSection(String(localized: "Excluded Apps")) {
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
        }
    }

    @MainActor
    func authenticateForSecurityChange(reason: String) async -> Bool {
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
}
