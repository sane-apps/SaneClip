import SwiftUI

/// Reusable empty state view with brand styling
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var accentColor: Color = .teal
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: isIPad ? 32 : 16) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 96 : 48))
                .foregroundStyle(accentColor.opacity(0.4))

            Text(title)
                .font(isIPad ? .largeTitle : .headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(isIPad ? .title2 : .subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 160 : 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "doc.on.clipboard",
        title: "No Clips Yet",
        message: "Copy something on your Mac and it will appear here."
    )
}
