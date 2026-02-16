import SwiftUI

/// Reusable empty state view with brand styling
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var accentColor: Color = .teal

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(accentColor.opacity(0.4))

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
