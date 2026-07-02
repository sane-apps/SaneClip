// Direct-distribution ONLY: this whole file is compiled exclusively into the
// direct (Sparkle) build. It must NEVER ship in Setapp or App Store binaries —
// the Setapp archive scanner hard-fails on the SaneSparkleRow symbol. That is
// also why this lives app-local instead of in shared SaneUI: a shared-library
// public type lands in every consumer binary regardless of call-site gating
// (caught live during the 2.3.12 Setapp package validation).
#if !APP_STORE && !SETAPP

    import SaneUI
    import SwiftUI

    enum SaneSparkleCheckFrequency: String, CaseIterable, Identifiable {
        case daily
        case weekly

        var id: String {
            rawValue
        }

        func title(labels: SaneSparkleRow.Labels) -> String {
            switch self {
            case .daily: labels.dailyTitle
            case .weekly: labels.weeklyTitle
            }
        }

        var interval: TimeInterval {
            switch self {
            case .daily: 60 * 60 * 24
            case .weekly: 60 * 60 * 24 * 7
            }
        }

        static func resolve(updateCheckInterval: TimeInterval) -> Self {
            let threshold = (Self.daily.interval + Self.weekly.interval) / 2
            return updateCheckInterval >= threshold ? .weekly : .daily
        }

        static func normalizedInterval(from updateCheckInterval: TimeInterval) -> TimeInterval {
            resolve(updateCheckInterval: updateCheckInterval).interval
        }
    }

    struct SaneSparkleRow: View {
        struct Labels {
            let automaticCheckLabel: String
            let automaticCheckHelp: String
            let checkFrequencyLabel: String
            let checkFrequencyHelp: String
            let actionsLabel: String
            let checkingLabel: String
            let checkNowLabel: String
            let checkNowHelp: String
            let dailyTitle: String
            let weeklyTitle: String
        }

        @Binding private var automaticallyChecks: Bool
        @Binding private var checkFrequency: SaneSparkleCheckFrequency
        private let isAvailable: Bool
        private let unavailableStatus: String?
        private let recoveryActionLabel: String?
        private let recoveryActionHelp: String?
        private let labels: Labels
        private let onCheckNow: () -> Void
        private let onRecoveryAction: (() -> Void)?
        @State private var isChecking = false

        init(
            automaticallyChecks: Binding<Bool>,
            checkFrequency: Binding<SaneSparkleCheckFrequency>,
            isAvailable: Bool = true,
            unavailableStatus: String? = nil,
            recoveryActionLabel: String? = nil,
            recoveryActionHelp: String? = nil,
            onRecoveryAction: (() -> Void)? = nil,
            labels: Labels,
            onCheckNow: @escaping () -> Void
        ) {
            _automaticallyChecks = automaticallyChecks
            _checkFrequency = checkFrequency
            self.isAvailable = isAvailable
            self.unavailableStatus = unavailableStatus
            self.recoveryActionLabel = recoveryActionLabel
            self.recoveryActionHelp = recoveryActionHelp
            self.labels = labels
            self.onCheckNow = onCheckNow
            self.onRecoveryAction = onRecoveryAction
        }

        var body: some View {
            if let unavailableStatus, !isAvailable {
                CompactRow("Status") {
                    Text(unavailableStatus)
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CompactDivider()

                if let recoveryActionLabel, let onRecoveryAction {
                    CompactRow(labels.actionsLabel) {
                        Button(recoveryActionLabel) {
                            onRecoveryAction()
                        }
                        .buttonStyle(SaneActionButtonStyle())
                        .help(recoveryActionHelp ?? recoveryActionLabel)
                    }

                    CompactDivider()
                }
            }

            CompactToggle(label: labels.automaticCheckLabel, isOn: $automaticallyChecks)
                .help(labels.automaticCheckHelp)
                .disabled(!isAvailable)

            CompactDivider()

            CompactRow(labels.checkFrequencyLabel) {
                Picker("", selection: $checkFrequency) {
                    ForEach(SaneSparkleCheckFrequency.allCases) { frequency in
                        Text(frequency.title(labels: labels)).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .disabled(!isAvailable || !automaticallyChecks)
            }
            .help(labels.checkFrequencyHelp)

            CompactDivider()

            CompactRow(labels.actionsLabel) {
                Button(isChecking ? labels.checkingLabel : labels.checkNowLabel) {
                    guard !isChecking else { return }
                    isChecking = true
                    onCheckNow()

                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(5))
                        isChecking = false
                    }
                }
                .buttonStyle(SaneActionButtonStyle())
                .disabled(isChecking || !isAvailable)
                .help(isAvailable ? labels.checkNowHelp : (unavailableStatus ?? labels.checkNowHelp))
            }
        }
    }

#endif
