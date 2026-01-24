import SwiftUI

/// Pinned tab showing pinned clipboard items
struct PinnedTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pinnedItems.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "pin.slash",
                        title: "No Pinned Clips",
                        message: "Pin items on your Mac to access them quickly here."
                    )
                } else {
                    List {
                        ForEach(viewModel.filteredPinned(searchText)) { item in
                            ClipboardItemCell(item: item, isPinned: true)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        viewModel.copyToClipboard(item)
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    .tint(Color.clipBlue)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search pinned")
                }
            }
            .navigationTitle("Pinned")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.pinnedOrange)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .tint(Color.pinnedOrange)
    }
}

#Preview {
    PinnedTab()
        .environmentObject(ClipboardHistoryViewModel())
}
