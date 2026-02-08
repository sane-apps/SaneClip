import SwiftUI

/// History tab showing recent clipboard items
struct HistoryTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @State private var searchText = ""
    @State private var selectedItem: SharedClipboardItem?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty, !viewModel.isLoading {
                    EmptyStateView(
                        icon: "doc.on.clipboard",
                        title: "No Clips Yet",
                        message: "Copy something on your Mac and it will appear here."
                    )
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
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
        .tint(Color.clipBlue)
    }

    // MARK: - Subviews

    private var historyList: some View {
        List {
            ForEach(viewModel.filteredHistory(searchText)) { item in
                historyRow(item)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search clips")
    }

    private func historyRow(_ item: SharedClipboardItem) -> some View {
        ClipboardItemCell(
            item: item,
            isPinned: false,
            isCopied: viewModel.copiedItemID == item.id
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
                .foregroundStyle(Color.clipBlue)
        }
        .disabled(viewModel.isLoading)
    }

    @ViewBuilder
    private var copiedToastOverlay: some View {
        if viewModel.copiedItemID != nil {
            CopiedToast()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Copied Toast

struct CopiedToast: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Copied")
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
