import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.teal.opacity(0.12),
                    Color.purple.opacity(0.08),
                    Color.teal.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                WelcomePageIOS(isIPad: isIPad)
                    .tag(0)

                FeaturesPageIOS(isIPad: isIPad)
                    .tag(1)

                SanePromisePageIOS(hasCompletedOnboarding: $hasCompletedOnboarding, isIPad: isIPad)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePageIOS: View {
    let isIPad: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            VStack(spacing: 0) {
                Spacer()

                // Hero section — icon, title, subtitle
                VStack(spacing: isIPad ? 24 : 16) {
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: isIPad ? 200 : 120,
                            height: isIPad ? 200 : 120
                        )
                        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 44 : 26))
                        .shadow(color: Color.teal.opacity(0.4), radius: 20, x: 0, y: 8)

                    Text("Welcome to SaneClip")
                        .font(.system(size: isIPad ? 52 : 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Everything you copy, saved automatically.\nText, images, links — always one tap away.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: isIPad ? 24 : 18))
                        .foregroundStyle(.white)
                        .padding(.horizontal, isIPad ? 80 : 24)
                }

                Spacer()

                // Trust badges — anchored in lower area
                HStack(spacing: isIPad ? 24 : 12) {
                    TrustBadgeIOS(icon: "lock.shield.fill", label: "100% Private", isIPad: isIPad)
                    TrustBadgeIOS(icon: "dollarsign.circle.fill", label: "No Subscription", isIPad: isIPad)
                    TrustBadgeIOS(icon: "chevron.left.forwardslash.chevron.right", label: "Open Source", isIPad: isIPad)
                }
                .padding(.horizontal, isIPad ? 60 : 20)
                .padding(.bottom, isIPad ? 60 : 40)
            }
            .frame(width: width)
        }
    }
}

private struct TrustBadgeIOS: View {
    let icon: String
    let label: String
    let isIPad: Bool

    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 32 : 22))
                .foregroundStyle(Color.teal)
            Text(label)
                .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 24 : 16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 18 : 12))
    }
}

// MARK: - Page 2: Features

private struct FeaturesPageIOS: View {
    let isIPad: Bool

    private let features: [(icon: String, color: Color, title: String, description: String)] = [
        ("doc.on.clipboard", .teal, "Clipboard History", "Every copy saved automatically"),
        ("pin.fill", .orange, "Pin & Annotate", "Pin favorites and add notes"),
        ("touchid", .red, "Touch ID & Encryption", "AES-256 encryption, biometric lock"),
        ("icloud", .blue, "iCloud Sync", "Your clips on all your devices"),
        ("exclamationmark.shield.fill", .yellow, "Sensitive Data Detection", "Flags passwords, credit cards, API keys"),
        ("photo", .green, "Images & Text", "Copies images too, not just text"),
        ("widget.small", .purple, "Home Screen Widgets", "Quick access without opening the app"),
        ("magnifyingglass", .white, "Instant Search", "Find anything you ever copied")
    ]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            VStack(spacing: 0) {
                Spacer()

                Text("What You Get")
                    .font(.system(size: isIPad ? 46 : 30, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, isIPad ? 48 : 24)

                if isIPad {
                    // iPad: 2-column grid with generous spacing
                    let leftColumn = Array(features.prefix(4))
                    let rightColumn = Array(features.suffix(4))

                    HStack(alignment: .top, spacing: 32) {
                        VStack(spacing: 28) {
                            ForEach(leftColumn.indices, id: \.self) { i in
                                FeatureRowIOS(
                                    icon: leftColumn[i].icon,
                                    color: leftColumn[i].color,
                                    title: leftColumn[i].title,
                                    description: leftColumn[i].description,
                                    isIPad: true
                                )
                            }
                        }

                        VStack(spacing: 28) {
                            ForEach(rightColumn.indices, id: \.self) { i in
                                FeatureRowIOS(
                                    icon: rightColumn[i].icon,
                                    color: rightColumn[i].color,
                                    title: rightColumn[i].title,
                                    description: rightColumn[i].description,
                                    isIPad: true
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 80)
                } else {
                    // iPhone: single column
                    VStack(spacing: 16) {
                        ForEach(features.indices, id: \.self) { i in
                            FeatureRowIOS(
                                icon: features[i].icon,
                                color: features[i].color,
                                title: features[i].title,
                                description: features[i].description,
                                isIPad: false
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .frame(width: width)
        }
    }
}

private struct FeatureRowIOS: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    var isIPad: Bool = false

    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 24 : 18))
                .foregroundStyle(color)
                .frame(
                    width: isIPad ? 52 : 36,
                    height: isIPad ? 52 : 36
                )
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: isIPad ? 12 : 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: isIPad ? 22 : 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: isIPad ? 18 : 15))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }
}

// MARK: - Page 3: Sane Promise

private struct SanePromisePageIOS: View {
    @Binding var hasCompletedOnboarding: Bool
    let isIPad: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            VStack(spacing: isIPad ? 28 : 16) {
                Spacer()

                Text("Our Sane Philosophy")
                    .font(.system(size: isIPad ? 46 : 30, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: isIPad ? 8 : 6) {
                    Text("\"For God has not given us a spirit of fear,")
                        .font(.system(size: isIPad ? 24 : 17))
                        .foregroundStyle(.white)
                    Text("but of power and of love and of a sound mind.\"")
                        .font(.system(size: isIPad ? 24 : 17))
                        .foregroundStyle(.white)
                    Text("— 2 Timothy 1:7")
                        .font(.system(size: isIPad ? 20 : 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 60 : 16)

                // Pillar cards — sized to content, not stretched
                HStack(alignment: .top, spacing: isIPad ? 20 : 10) {
                    SanePillarCardIOS(
                        icon: "bolt.fill",
                        color: .yellow,
                        title: "Power",
                        lines: [
                            "Your data stays on-device",
                            "Open source code",
                            "Actively maintained"
                        ],
                        isIPad: isIPad
                    )

                    SanePillarCardIOS(
                        icon: "heart.fill",
                        color: .pink,
                        title: "Love",
                        lines: [
                            "Built to serve you",
                            "No subscriptions",
                            "No ads, ever"
                        ],
                        isIPad: isIPad
                    )

                    SanePillarCardIOS(
                        icon: "brain.head.profile",
                        color: .purple,
                        title: "Sound Mind",
                        lines: [
                            "Calm and focused",
                            "Does one thing well",
                            "No clutter"
                        ],
                        isIPad: isIPad
                    )
                }
                .padding(.horizontal, isIPad ? 60 : 12)

                Spacer()

                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.system(size: isIPad ? 22 : 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: isIPad ? 440 : .infinity)
                        .padding(.vertical, isIPad ? 18 : 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.teal)
                .padding(.horizontal, isIPad ? 100 : 40)
                .padding(.bottom, isIPad ? 50 : 36)
            }
            .frame(width: width)
        }
    }
}

private struct SanePillarCardIOS: View {
    let icon: String
    let color: Color
    let title: String
    let lines: [String]
    var isIPad: Bool = false

    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 36 : 26))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: isIPad ? 24 : 18, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: isIPad ? 8 : 5) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: isIPad ? 14 : 11, weight: .bold))
                            .foregroundStyle(.green)
                            .frame(width: isIPad ? 18 : 14)
                            .padding(.top, isIPad ? 4 : 3)
                        Text(line)
                            .font(.system(size: isIPad ? 18 : 15))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.vertical, isIPad ? 28 : 16)
        .padding(.horizontal, isIPad ? 16 : 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 20 : 14))
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
