import SaneUI
import SwiftUI

/// The bottom toolbar of the history window: item count, merge-queue and
/// paste-stack controls, settings, and Smart Clear.
///
/// Extracted from `ClipboardHistoryView` both to keep that view under the
/// component size limit and to fix the squashed-toolbar bug Glenn reported: at
/// narrow widths the inline controls wrapped character-by-character and the
/// horizontal scrollbar could cover "Clear Queue". The secondary controls now
/// get their own row instead of a horizontal scroller.
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
        VStack(alignment: .leading, spacing: 0) {
            // Contextual controls (merge queue, paste stack) rise in a band
            // ABOVE the persistent bar, so the anchors below never move as
            // they come and go.
            if showsSecondaryControls {
                secondaryControls
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                Divider()
            }

            // Persistent anchor bar — item count pinned bottom-left, the fixed
            // actions pinned bottom-right. Same place every time, whatever else
            // is going on above it.
            HStack(spacing: 8) {
                itemCountLabel
                Spacer(minLength: 8)
                settingsButton
                smartClearButton
            }
            .padding(8)
        }
    }

    private var showsSecondaryControls: Bool {
        !mergeQueueIDs.isEmpty || showsPasteStackCluster || showsPasteStackUpsell
    }

    /// The Pro paste-stack cluster appears only when it has something to act
    /// on — queued items, or the panel already open — never as an empty "0"
    /// chip claiming a whole footer row in the common just-opened state.
    private var showsPasteStackCluster: Bool {
        isPro && (!clipboardManager.pasteStack.isEmpty || showPasteStackPanel || clipboardManager.isRecordingStack)
    }

    private var showsPasteStackUpsell: Bool {
        !isPro && licenseService != nil
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

    // MARK: - Secondary controls (second row at narrow widths)

    @ViewBuilder private var secondaryControls: some View {
        if hasMergeAndPasteStack {
            stackedSecondaryControls
        } else {
            HStack(spacing: 8) {
                if !mergeQueueIDs.isEmpty {
                    mergeControls
                }
                pasteStackGroup
            }
        }
    }

    private var hasMergeAndPasteStack: Bool {
        !mergeQueueIDs.isEmpty && (showsPasteStackCluster || showsPasteStackUpsell)
    }

    private var stackedSecondaryControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            mergeControls
            pasteStackGroup
        }
    }

    @ViewBuilder private var pasteStackGroup: some View {
        if showsPasteStackCluster {
            pasteStackCluster
        } else if showsPasteStackUpsell {
            pasteStackUpsell
        }
    }

    private var mergeControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "link.badge.plus")
                    .font(.caption)
                Text("\(mergeQueueIDs.count)")
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundStyle(Color.mergeTeal)
            .help("Items queued for merge")

            Button("Merge") { onMerge() }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Color.mergeTeal)
                .fixedSize()
                .disabled(mergeQueueIDs.count < 2)

            Button("Delete") {
                clipboardManager.removeHistoryItems(withIDs: mergeQueueIDs)
                mergeQueueIDs.removeAll()
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(Color.semanticError.opacity(0.95))
            .fixedSize()
            .help("Delete the \(mergeQueueIDs.count) selected item(s)")

            Button("Clear Queue") { mergeQueueIDs.removeAll() }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    private var pasteStackCluster: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                // Recording indicator: while build-by-copying is on, the stack
                // icon becomes a filled record dot so it's visible even with
                // the panel closed. Stays violet — recording is a stack action.
                Image(systemName: clipboardManager.isRecordingStack ? "record.circle.fill" : "square.stack.3d.up")
                    .font(.caption)
                    .help(clipboardManager.isRecordingStack ? "Recording copies to the stack" : "Items in paste stack")
                Text("\(clipboardManager.pasteStack.count)")
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundStyle(Color.stackViolet)
            .help("Items in paste stack")

            Button(SettingsModel.shared.pausePasteStackConsumption ? "Paused" : "Paste") {
                clipboardManager.pasteFromStack()
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(Color.stackViolet)
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
        }
    }

    private var pasteStackUpsell: some View {
        HStack(spacing: 8) {
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
                .foregroundStyle(Color.proUnlock)
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
