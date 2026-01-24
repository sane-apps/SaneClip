import SwiftUI

/// History tab showing recent clipboard items
struct HistoryTab: View {
    @EnvironmentObject var viewModel: ClipboardHistoryViewModel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "doc.on.clipboard",
                        title: "No Clips Yet",
                        message: "Copy something on your Mac and it will appear here."
                    )
                } else {
                    List {
                        ForEach(viewModel.filteredHistory(searchText)) { item in
                            ClipboardItemCell(item: item, isPinned: false)
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
                    .searchable(text: $searchText, prompt: "Search clips")
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.clipBlue)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .tint(Color.clipBlue)
    }
}

#Preview {
    HistoryTab()
        .environmentObject(ClipboardHistoryViewModel())
}
