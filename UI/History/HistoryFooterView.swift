import SaneUI
import SwiftUI

/// The bottom toolbar of the history window: item count, merge-queue and
/// paste-stack controls, settings, and Smart Clear.
///
/// Extracted from `ClipboardHistoryView` both to keep that view under the
/// component size limit and to fix the squashed-toolbar bug Glenn reported: at
/// narrow widths the inline controls wrapped character-by-character. The status
/// cluster now lives in a horizontal scroll view so it never compresses, while
/// Settings and Smart Clear stay pinned to the trailing edge.
struct HistoryFooterView: View {
    var clipboardManager: ClipboardManager
    var licenseService: LicenseService?
    var hasActiveFilters: Bool
    var shownCount: Int
    var smartClearRemovableCount: Int
    @Binding var mergeQueueIDs: Set<UUID>
    @Binding var showPasteStackPanel: Bool
    @Binding var showSmartClearConfirmation: Bool
    var focusedTarget: FocusState<ClipboardHistoryView.FocusTarget?>.Binding
    var onMerge: () -> Void

    private var isPro: Bool {
        licenseService?.isPro == true
    }

    var body: some View {
        HStack(spacing: 8) {
            // Item count stays pinned (always visible) — it is the primary
            // status readout and must never scroll out of view.
            itemCountLabel

            // Only the secondary action controls (merge queue, paste stack)
            // live in the scroll view, so at narrow widths they degrade to a
            // horizontal scroll (with an indicator) instead of squashing or
            // pushing the essentials off-screen.
            ScrollView(.horizontal, showsIndicators: true) {
                secondaryControls
                    .padding(.trailing, 8)
            }

            settingsButton
            smartClearButton
        }
        .padding(8)
    }

    private var itemCountLabel: some View {
        HStack(spacing: 6) {
            Text("\(clipboardManager.history.count) items")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel("\(clipboardManager.history.count) clipboard items")

            if hasActiveFilters {
                Text("(\(shownCount) shown)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    // MARK: - Secondary controls (scroll horizontally at narrow widths)

    private var secondaryControls: some View {
        HStack(spacing: 8) {
            if !mergeQueueIDs.isEmpty {
                Divider().frame(height: 14)
                HStack(spacing: 4) {
                    Image(systemName: "link.badge.plus")
                        .font(.caption)
                    Text("\(mergeQueueIDs.count)")
                        .font(.subheadline.monospacedDigit())
                }
                .foregroundStyle(.teal)
                .help("Items queued for merge")

                Button("Merge") { onMerge() }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.teal)
                    .fixedSize()
                    .disabled(mergeQueueIDs.count < 2)

                Button("Clear Queue") { mergeQueueIDs.removeAll() }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            pasteStackControls
        }
    }

    @ViewBuilder
    private var pasteStackControls: some View {
        if isPro {
            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Image(systemName: "square.stack.3d.up")
                    .font(.caption)
                Text("\(clipboardManager.pasteStack.count)")
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundStyle(.orange)
            .help("Items in paste stack")

            Button(SettingsModel.shared.pausePasteStackConsumption ? "Paused" : "Paste") {
                clipboardManager.pasteFromStack()
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(.orange)
            .fixedSize()
            .disabled(SettingsModel.shared.pausePasteStackConsumption || clipboardManager.pasteStack.isEmpty)

            Button(showPasteStackPanel ? "Hide" : "Stack") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showPasteStackPanel.toggle()
                }
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize()
        } else {
            Divider().frame(height: 14)
            Button {
                if let ls = licenseService {
                    ProUpsellWindow.show(feature: ProFeature.pasteStack, licenseService: ls)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Stack")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Pro")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.teal)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Unlock Paste Stack with Pro")
        }
    }

    // MARK: - Pinned trailing controls

    private var settingsButton: some View {
        Button(
            action: { SettingsWindowController.open() },
            label: { Image(systemName: "gear") }
        )
        .buttonStyle(.plain)
        .keyboardShortcut(",", modifiers: .command)
        .focusable()
        .focused(focusedTarget, equals: .settingsButton)
        .help("Settings")
        .accessibilityLabel("Open settings")
    }

    private var smartClearButton: some View {
        Button {
            showSmartClearConfirmation = true
        } label: {
            Label("Smart Clear", systemImage: "sparkles")
        }
        .buttonStyle(.plain)
        .focusable()
        .focused(focusedTarget, equals: .smartClearButton)
        .font(.subheadline)
        .foregroundStyle(Color.clipBlue.opacity(0.95))
        .fixedSize()
        .help("Bulk-delete disposable clips while keeping pinned, tagged, noted, and non-default collection items.")
        .accessibilityLabel("Smart clear clipboard history")
        .accessibilityHint("Opens safe bulk delete options for disposable items only.")
        .disabled(smartClearRemovableCount == 0)
    }
}
