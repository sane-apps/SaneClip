import SaneUI
import SwiftUI

/// The expandable filter row (date / type / collection / tag pickers + saved
/// presets), shown under the search bar when filters are toggled on.
///
/// Extracted from `ClipboardHistoryView` to keep it under the size limit and to
/// fix narrow-width clipping: the four fixed-width pickers (~440pt) overflowed
/// the 300–320pt window/popover, colliding with the Save/Clear buttons. The
/// pickers now live in a horizontal scroll view; Save Current / Clear Filters
/// stay pinned on the trailing edge.
struct HistoryFilterBar: View {
    @Binding var dateFilter: DateFilter
    @Binding var contentTypeFilter: ContentTypeFilter
    @Binding var selectedCollection: String
    @Binding var selectedTag: String
    @Binding var savedPresets: [HistoryFilterPreset]
    @Binding var showSavePresetSheet: Bool
    @Binding var presetName: String
    let allCollections: [String]
    let allTags: [String]
    let hasActiveFilters: Bool
    let onApplyPreset: (HistoryFilterPreset) -> Void
    let onPersistPresets: () -> Void
    let onClearFilters: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Picker("Date", selection: $dateFilter) {
                        ForEach(DateFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 110)

                    Picker("Type", selection: $contentTypeFilter) {
                        ForEach(ContentTypeFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 80)

                    Picker("Collection", selection: $selectedCollection) {
                        ForEach(allCollections, id: \.self) { collection in
                            Text(collection).tag(collection)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)

                    Picker("Tag", selection: $selectedTag) {
                        ForEach(allTags, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)

                    if !savedPresets.isEmpty {
                        Menu("Saved") {
                            ForEach(savedPresets) { preset in
                                Button(preset.name) { onApplyPreset(preset) }
                            }
                            Divider()
                            Button("Clear Saved Presets") {
                                savedPresets = []
                                onPersistPresets()
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 90)
                    }
                }
                .padding(.trailing, 8)
            }

            Button("Save Current") {
                presetName = ""
                showSavePresetSheet = true
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(Color.clipBlue)
            .fixedSize()

            if hasActiveFilters {
                Button("Clear Filters") { onClearFilters() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.clipBlue)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background.tertiary)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
