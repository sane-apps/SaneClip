import AppKit
import SaneUI
import SwiftUI

struct GeneralSettingsView: View {
    @State var settings = SettingsModel.shared
    #if !APP_STORE && !SETAPP
        @State private var autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
        @State private var updateCheckFrequency = UpdateService.shared.updateCheckFrequency
    #else
        @State private var autoCheckUpdates = false
    #endif

    var body: some View {
        SaneSettingsPage {
            Text(String(localized: "General"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            CompactSection(SaneClipSettingsCopy.startupSectionTitle) {
                SaneLoginItemToggle()
                CompactDivider()
                SaneDockIconToggle(showDockIcon: Binding(
                    get: { settings.showInDock },
                    set: { settings.showInDock = $0 }
                ))
            }

            CompactSection(String(localized: "Menu Bar")) {
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
            }

            SaneLanguageSettingsRow()

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
        }
        .onAppear {
            #if !APP_STORE && !SETAPP
                autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
                updateCheckFrequency = UpdateService.shared.updateCheckFrequency
            #endif
        }
    }
}
