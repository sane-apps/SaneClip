import SwiftUI
import UIKit

/// Drag-out payload for history/pinned rows: text drops as plain text, images
/// drop as images (UIImage conforms to NSItemProviderWriting). Mirrors the Mac
/// ClipboardItemRow.dragItemProvider so clips drag into other apps in Split
/// View / Slide Over the same way they drag out of the Mac history window.
enum ClipDragPayload {
    static func itemProvider(for item: SharedClipboardItem) -> NSItemProvider {
        switch item.content {
        case let .text(string):
            return NSItemProvider(object: string as NSString)
        case let .imageData(data, _, _):
            guard let image = UIImage(data: data) else { return NSItemProvider() }
            return NSItemProvider(object: image)
        }
    }
}

/// Share affordance for a clip row: text shares as plain text, images share
/// as images. Used by the History and Pinned context menus and the detail view.
struct ClipShareLink: View {
    let item: SharedClipboardItem

    var body: some View {
        if let text = item.fullText {
            ShareLink(item: text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } else if case let .imageData(data, _, _) = item.content,
                  let uiImage = UIImage(data: data) {
            ShareLink(
                item: Image(uiImage: uiImage),
                preview: SharePreview("Image", image: Image(uiImage: uiImage))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}

/// History tab showing recent clipboard items
struct HistoryTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var searchText = ""
    @State private var selectedItem: SharedClipboardItem?

    private var isIPad: Bool {
        sizeClass == .regular
    }

    private let isScreenshotMode = LaunchOptions.isScreenshotMode()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty, !viewModel.isLoading {
                    VStack(spacing: 0) {
                        if viewModel.hasPendingClipboardContent, !isScreenshotMode {
                            pendingClipboardCard
                        }
                        EmptyStateView(
                            icon: "doc.on.clipboard",
                            title: "No Clips Yet",
                            message: "Turn on iCloud Sync on your Mac to see synced history here.\n\nYou can also tap + to save the current iPhone clipboard or use the Share menu from another app."
                        )
                    }
                } else {
                    VStack(spacing: 0) {
                        if viewModel.isShowingDemoData, !isScreenshotMode {
                            demoBanner
                        }
                        if viewModel.hasPendingClipboardContent, !isScreenshotMode {
                            pendingClipboardCard
                        }
                        historyList
                    }
                }
            }
            .navigationTitle("History")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if !isScreenshotMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        saveClipboardButton
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $selectedItem) { item in
                ClipboardDetailView(item: item, viewModel: viewModel)
            }
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .task {
                #if DEBUG
                    viewModel.forcePendingClipboardCardPreviewIfRequested()
                #endif
                viewModel.checkForNewClipboardContent()
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.copiedItemID)
            .animation(.easeInOut(duration: 0.2), value: viewModel.savedItemID)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.checkForNewClipboardContent()
                }
            }
        }
    }

    // MARK: - Subviews

    private var saveClipboardButton: some View {
        Button {
            viewModel.saveCurrentClipboard()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(isIPad ? .title : .title3)
        }
        .accessibilityLabel("Save current clipboard")
    }

    private var demoBanner: some View {
        HStack(spacing: isIPad ? 16 : 8) {
            Image(systemName: "info.circle.fill")
                .font(isIPad ? .title : .callout)
                .foregroundStyle(.white)
            Text("Sample data shown. Install SaneClip on your Mac and enable iCloud Sync to see your real clipboard history.")
                .font(isIPad ? .title2 : .caption)
                .foregroundStyle(.white)
        }
        .padding(isIPad ? 28 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandNavy)
    }

    private var pendingClipboardCard: some View {
        HStack(spacing: isIPad ? 18 : 10) {
            Button {
                viewModel.saveCurrentClipboard()
            } label: {
                HStack(spacing: isIPad ? 18 : 10) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(isIPad ? .largeTitle : .title3)
                        .foregroundStyle(.white)
                        .frame(width: isIPad ? 44 : 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.pendingClipboardTitle)
                            .font(isIPad ? .title2.weight(.semibold) : .subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(viewModel.pendingClipboardSubtitle)
                            .font(isIPad ? .body : .caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(isIPad ? .title : .title3)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.pendingClipboardTitle)
            .accessibilityHint("Saves the current iPhone clipboard to SaneClip history")

            Button {
                viewModel.dismissClipboardDetection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(isIPad ? .title : .title3)
                    .foregroundStyle(.white)
                    .frame(width: isIPad ? 44 : 32, height: isIPad ? 44 : 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss clipboard save prompt")
            .accessibilityHint("Hides this prompt until the iPhone clipboard changes again")
        }
        .padding(isIPad ? 28 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clipBlue.opacity(0.95))
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.filteredHistory(searchText)) { item in
                historyRow(item)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search clips")
    }

    private func historyRow(_ item: SharedClipboardItem) -> some View {
        ClipboardItemCell(
            item: item,
            isPinned: viewModel.isPinned(item),
            isCopied: viewModel.copiedItemID == item.id
        )
        .listRowInsets(EdgeInsets(
            top: isIPad ? 10 : 4,
            leading: isIPad ? 64 : 12,
            bottom: isIPad ? 10 : 4,
            trailing: isIPad ? 64 : 12
        ))
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        // Unconditional drag-out: unlike the Mac list there is no .onMove
        // reorder on iOS, so no pinned-row gating is needed. If reorder is
        // ever added, re-add the Mac's onDragOut(enabled: !isPinned) gate.
        .onDrag {
            ClipDragPayload.itemProvider(for: item)
        }
        .onTapGesture {
            viewModel.copyToClipboard(item)
        }
        .contextMenu {
            Button {
                viewModel.copyToClipboard(item)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                viewModel.togglePin(item)
            } label: {
                Label(
                    viewModel.isPinned(item) ? "Unpin" : "Pin",
                    systemImage: viewModel.isPinned(item) ? "pin.slash" : "pin"
                )
            }
            Button {
                selectedItem = item
            } label: {
                Label("Details", systemImage: "info.circle")
            }
            ClipShareLink(item: item)
            Divider()
            Button(role: .destructive) {
                viewModel.deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                viewModel.copyToClipboard(item)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(Color.clipBlue)
        }
        .accessibilityLabel(item.accessibilityDescription)
        .accessibilityHint("Tap to copy, long press for options")
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(isIPad ? .title2 : .body)
        }
        .disabled(viewModel.isLoading)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if viewModel.copiedItemID != nil {
            ToastView(icon: "checkmark.circle.fill", text: "Copied", color: Color.clipBlue)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 16)
        } else if viewModel.savedItemID != nil {
            ToastView(icon: "plus.circle.fill", text: "Saved", color: Color.clipBlue)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let icon: String
    let text: String
    let color: Color
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isIPad: Bool {
        sizeClass == .regular
    }

    var body: some View {
        HStack(spacing: isIPad ? 10 : 6) {
            Image(systemName: icon)
                .font(isIPad ? .title3 : .subheadline)
                .foregroundStyle(color)
            Text(text)
                .font(isIPad ? .title3.weight(.medium) : .subheadline.weight(.medium))
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.vertical, isIPad ? 14 : 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    HistoryTab()
        .environmentObject(ClipboardHistoryViewModel())
}
