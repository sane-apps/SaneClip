import SwiftUI

/// History tab showing recent clipboard items
struct HistoryTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var selectedItem: SharedClipboardItem?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty, !viewModel.isLoading {
                    EmptyStateView(
                        icon: "doc.on.clipboard",
                        title: "No Clips Yet",
                        message: "Tap the + button to save your current clipboard, or use the Share menu from any app.\n\nEnable iCloud Sync to see your Mac clipboard history here too."
                    )
                } else {
                    VStack(spacing: 0) {
                        if viewModel.isShowingDemoData {
                            demoBanner
                        }
                        if viewModel.clipboardDetectedText != nil {
                            clipboardDetectedBanner
                        }
                        historyList
                    }
                }
            }
            .navigationTitle("SaneClip")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    saveClipboardButton
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
                .font(.title3)
        }
        .accessibilityLabel("Save current clipboard")
    }

    private var demoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.white)
            Text("Sample data shown. Install SaneClip on your Mac and enable iCloud Sync to see your real clipboard history.")
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandNavy)
    }

    private var clipboardDetectedBanner: some View {
        Button {
            viewModel.saveCurrentClipboard()
            viewModel.dismissClipboardDetection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundStyle(.white)
                Text("New clipboard content — tap to save")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brandNavy.opacity(0.9))
        }
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
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
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
            .tint(.teal)
        }
        .accessibilityLabel(item.accessibilityDescription)
        .accessibilityHint("Tap to copy, long press for options")
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if viewModel.copiedItemID != nil {
            ToastView(icon: "checkmark.circle.fill", text: "Copied", color: .teal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 16)
        } else if viewModel.savedItemID != nil {
            ToastView(icon: "plus.circle.fill", text: "Saved", color: .teal)
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    HistoryTab()
        .environmentObject(ClipboardHistoryViewModel())
}
