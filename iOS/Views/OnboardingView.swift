import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Background gradient matching brand
            LinearGradient(
                colors: [
                    Color.clipBlue.opacity(0.08),
                    Color.purple.opacity(0.05),
                    Color.clipBlue.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                WelcomePageIOS()
                    .tag(0)

                FeaturesPageIOS()
                    .tag(1)

                SanePromisePageIOS(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePageIOS: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.clipBlue)
                .shadow(color: Color.clipBlue.opacity(0.3), radius: 10, x: 0, y: 5)

            Text("Welcome to SaneClip")
                .font(.system(size: 32, weight: .bold))

            Text("Your clipboard history, always accessible.\nFast, private, and secure.")
                .multilineTextAlignment(.center)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Page 2: Features

private struct FeaturesPageIOS: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("What You Get")
                .font(.system(size: 28, weight: .bold))

            VStack(spacing: 20) {
                FeatureRow(
                    icon: "doc.on.clipboard",
                    color: .clipBlue,
                    title: "Clipboard History",
                    description: "Access your recent copies from any app"
                )

                FeatureRow(
                    icon: "pin.fill",
                    color: .pinnedOrange,
                    title: "Pin Important Items",
                    description: "Keep frequently used text one tap away"
                )

                FeatureRow(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "Privacy First",
                    description: "Your data stays on your device"
                )

                FeatureRow(
                    icon: "widget.small",
                    color: .purple,
                    title: "Home Screen Widgets",
                    description: "Quick access without opening the app"
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Page 3: Sane Promise

private struct SanePromisePageIOS: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Our Sane Philosophy")
                .font(.system(size: 28, weight: .bold))

            VStack(spacing: 8) {
                Text("\"For God has not given us a spirit of fear,")
                    .font(.system(size: 16))
                    .italic()
                Text("but of power and of love and of a sound mind.\"")
                    .font(.system(size: 16))
                    .italic()
                Text("-- 2 Timothy 1:7")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                SanePillarCardIOS(
                    icon: "bolt.fill",
                    color: .yellow,
                    title: "Power"
                )

                SanePillarCardIOS(
                    icon: "heart.fill",
                    color: .pink,
                    title: "Love"
                )

                SanePillarCardIOS(
                    icon: "brain.head.profile",
                    color: .purple,
                    title: "Sound Mind"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.clipBlue)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .padding()
    }
}

private struct SanePillarCardIOS: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
