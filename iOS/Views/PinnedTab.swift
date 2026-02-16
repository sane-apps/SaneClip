import SwiftUI

/// Pinned tab showing pinned clipboard items
struct PinnedTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @State private var searchText = ""
    @State private var selectedItem: SharedClipboardItem?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pinnedItems.isEmpty, !viewModel.isLoading {
                    EmptyStateView(
                        icon: "pin.slash",
                        title: "No Pinned Clips",
                        message: "Pin items on your Mac to access them quickly here.",
                        accentColor: .pinnedOrange
                    )
                } else {
                    pinnedList
                }
            }
            .navigationTitle("Pinned")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
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
                copiedToastOverlay
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.copiedItemID)
        }
        .tint(Color.pinnedOrange)
    }

    // MARK: - Subviews

    private var pinnedList: some View {
        List {
            ForEach(viewModel.filteredPinned(searchText)) { item in
                pinnedRow(item)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search pinned")
    }

    private func pinnedRow(_ item: SharedClipboardItem) -> some View {
        ClipboardItemCell(
            item: item,
            isPinned: true,
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
                selectedItem = item
            } label: {
                Label("Details", systemImage: "info.circle")
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                viewModel.copyToClipboard(item)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(Color.pinnedOrange)
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
    private var copiedToastOverlay: some View {
        if viewModel.copiedItemID != nil {
            ToastView(icon: "checkmark.circle.fill", text: "Copied", color: Color.teal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 16)
        }
    }
}

#Preview {
    PinnedTab()
        .environmentObject(ClipboardHistoryViewModel())
}
