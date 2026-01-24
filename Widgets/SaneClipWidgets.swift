import SwiftUI
import WidgetKit

@main
struct SaneClipWidgets: WidgetBundle {
    var body: some Widget {
        RecentClipsWidget()
        PinnedClipsWidget()
    }
}
