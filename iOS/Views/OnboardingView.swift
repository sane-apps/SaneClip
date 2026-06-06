import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let pages = CompanionOnboardingPage.pages
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    CompanionOnboardingPageView(page: page, isIPad: isIPad)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.brandNavy.opacity(0.92),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.28))
                    .foregroundStyle(.white)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.clipBlue)
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.clipBlue)
                }
            }
            .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
            .padding(.horizontal, isIPad ? 28 : 20)
            .padding(.vertical, isIPad ? 18 : 14)
            .background(Color.black.opacity(0.44))
        }
    }
}

private struct CompanionOnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let rows: [CompanionOnboardingRow]

    static let pages: [CompanionOnboardingPage] = [
        CompanionOnboardingPage(
            icon: "iphone.and.arrow.forward",
            title: "SaneClip Companion",
            subtitle: "Use your iPhone or iPad to view, search, and copy the clipboard history you sync from your Mac.",
            rows: [
                CompanionOnboardingRow(icon: "desktopcomputer", title: "Mac is the full app", detail: "Paste Stack, Smart Paste, snippets, rules, OCR, Touch ID, and encryption live on Mac."),
                CompanionOnboardingRow(icon: "iphone", title: "iPhone is the companion", detail: "Browse synced clips, copy them, pin favorites, and save the current iPhone clipboard.")
            ]
        ),
        CompanionOnboardingPage(
            icon: "icloud",
            title: "Sync Through iCloud",
            subtitle: "Turn on iCloud Sync on your Mac and this device to see the same history while the companion app is active.",
            rows: [
                CompanionOnboardingRow(icon: "person.crop.circle.badge.checkmark", title: "Your iCloud account", detail: "SaneApps does not run a clipboard sync server."),
                CompanionOnboardingRow(icon: "arrow.clockwise", title: "Refresh when needed", detail: "Use Sync Now if a clip has not appeared yet.")
            ]
        ),
        CompanionOnboardingPage(
            icon: "doc.on.clipboard",
            title: "Save iPhone Clipboard",
            subtitle: "iOS only exposes the current pasteboard. SaneClip can save what is available now, not old overwritten copies.",
            rows: [
                CompanionOnboardingRow(icon: "plus.circle.fill", title: "Use the plus button", detail: "Save the current iPhone clipboard into SaneClip history."),
                CompanionOnboardingRow(icon: "square.and.arrow.up", title: "Use the Share sheet", detail: "Send text and links from other apps into SaneClip.")
            ]
        ),
        CompanionOnboardingPage(
            icon: "lock.shield",
            title: "Private By Default",
            subtitle: "Clipboard contents stay on your devices unless you enable iCloud Sync or another explicit export path.",
            rows: [
                CompanionOnboardingRow(icon: "hand.raised.fill", title: "No ad tracking", detail: "No advertising SDKs and no SaneApps clipboard-content server."),
                CompanionOnboardingRow(icon: "questionmark.bubble", title: "Need help?", detail: "Settings links to the website and privacy policy; support lives at saneclip.com/support.")
            ]
        )
    ]
}

private struct CompanionOnboardingRow {
    let icon: String
    let title: String
    let detail: String
}

private struct CompanionOnboardingPageView: View {
    let page: CompanionOnboardingPage
    let isIPad: Bool

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isIPad ? 24 : 18) {
                    Spacer(minLength: isIPad ? 46 : 28)

                    Image(systemName: page.icon)
                        .font(.system(size: isIPad ? 72 : 52, weight: .semibold))
                        .foregroundStyle(Color.clipBlue)
                        .frame(width: isIPad ? 128 : 92, height: isIPad ? 128 : 92)
                        .background(Color.clipBlue.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 30 : 22))

                    Text(page.title)
                        .font(.system(size: isIPad ? 46 : 32, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: isIPad ? 760 : 340)

                    Text(page.subtitle)
                        .font(.system(size: isIPad ? 23 : 17, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: isIPad ? 720 : 330)

                    VStack(spacing: isIPad ? 14 : 10) {
                        ForEach(page.rows, id: \.title) { row in
                            CompanionOnboardingRowView(row: row, isIPad: isIPad)
                        }
                    }
                    .frame(maxWidth: isIPad ? 720 : 340)

                    Spacer(minLength: isIPad ? 42 : 28)
                }
                .frame(minHeight: geo.size.height, alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isIPad ? 52 : 20)
            }
        }
    }
}

private struct CompanionOnboardingRowView: View {
    let row: CompanionOnboardingRow
    let isIPad: Bool

    var body: some View {
        HStack(alignment: .top, spacing: isIPad ? 16 : 12) {
            Image(systemName: row.icon)
                .font(.system(size: isIPad ? 23 : 17, weight: .semibold))
                .foregroundStyle(Color.clipBlue)
                .frame(width: isIPad ? 48 : 38, height: isIPad ? 48 : 38)
                .background(Color.clipBlue.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: isIPad ? 13 : 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(size: isIPad ? 21 : 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(row.detail)
                    .font(.system(size: isIPad ? 18 : 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(isIPad ? 16 : 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 16 : 12))
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
