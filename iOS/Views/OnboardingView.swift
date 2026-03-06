import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let totalPages = 7
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.teal.opacity(0.12),
                        Color.teal.opacity(0.08),
                        Color.teal.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                TabView(selection: $currentPage) {
                    WelcomePageIOS(isIPad: isIPad).tag(0)
                    DontSkipPageIOS(isIPad: isIPad).tag(1)
                    CoreWorkflowPageIOS(isIPad: isIPad).tag(2)
                    AdvancedWorkflowPageIOS(isIPad: isIPad).tag(3)
                    SanePhilosophyPageIOS(isIPad: isIPad).tag(4)
                    PermissionsPageIOS(isIPad: isIPad).tag(5)
                    PlanUpgradePageIOS(isIPad: isIPad).tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.25))
                    .foregroundStyle(.white)
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                }
            }
            .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
            .padding(.horizontal, isIPad ? 28 : 20)
            .padding(.vertical, isIPad ? 18 : 14)
            .background(Color.black.opacity(0.28))
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePageIOS: View {
    let isIPad: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: isIPad ? 26 : 18) {
                Spacer()

                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: isIPad ? 180 : 120, height: isIPad ? 180 : 120)
                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 40 : 26))
                    .shadow(color: Color.teal.opacity(0.35), radius: 20, x: 0, y: 8)

                Text("Welcome to SaneClip")
                    .font(.system(size: isIPad ? 50 : 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Clipboard history that stays calm, private, and fast.")
                    .font(.system(size: isIPad ? 24 : 18, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isIPad ? 80 : 24)

                Text("Seven quick screens. Follow them in order.")
                    .font(.system(size: isIPad ? 18 : 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                HStack(spacing: isIPad ? 20 : 12) {
                    TrustBadgeIOS(icon: "lock.shield.fill", label: "100% Private", isIPad: isIPad)
                    TrustBadgeIOS(icon: "dollarsign.circle.fill", label: "Pay Once", isIPad: isIPad)
                    TrustBadgeIOS(icon: "chevron.left.forwardslash.chevron.right", label: "Transparent", isIPad: isIPad)
                }
                .padding(.horizontal, isIPad ? 60 : 20)
                .padding(.bottom, isIPad ? 56 : 36)
            }
            .frame(width: geo.size.width)
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
                .font(.system(size: isIPad ? 30 : 22))
                .foregroundStyle(.teal)
            Text(label)
                .font(.system(size: isIPad ? 18 : 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 22 : 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 16 : 12))
    }
}

// MARK: - Page 2: Don't Skip

private struct DontSkipPageIOS: View {
    let isIPad: Bool

    var body: some View {
        VStack(spacing: isIPad ? 28 : 20) {
            Spacer()

            Image(systemName: "hand.wave.fill")
                .font(.system(size: isIPad ? 66 : 46))
                .foregroundStyle(.teal)

            Text("Don't skip this.")
                .font(.system(size: isIPad ? 52 : 34, weight: .bold))
                .foregroundStyle(.white)

            Text("It's only a few screens and you'll be confused if you rush through.")
                .font(.system(size: isIPad ? 24 : 18))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 100 : 26)

            Text("— Mr. Sane")
                .font(.system(size: isIPad ? 20 : 15, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.95))

            Spacer()
        }
    }
}

// MARK: - Page 3: Core Workflow

private struct CoreWorkflowPageIOS: View {
    let isIPad: Bool

    private let steps: [(icon: String, color: Color, title: String, description: String)] = [
        ("doc.on.doc", .teal, "Copy Anything", "Text, links, and images are saved automatically"),
        ("line.3.horizontal.decrease.circle", .cyan, "Find Fast", "Search by content, app source, or date"),
        ("pin.fill", .orange, "Pin Important", "Keep your high-value clips at the top"),
        ("keyboard", .green, "Paste Quickly", "Use shortcuts to paste exactly what you want"),
        ("iphone", .blue, "Stay in Sync", "Use companion apps with iCloud when enabled")
    ]

    var body: some View {
        WorkflowListPageIOS(
            titlePrefix: "Core ",
            titleAccent: "Workflow",
            subtitle: "The daily loop: capture, find, and paste.",
            rows: steps,
            isIPad: isIPad
        )
    }
}

// MARK: - Page 4: Advanced Workflow

private struct AdvancedWorkflowPageIOS: View {
    let isIPad: Bool

    private let steps: [(icon: String, color: Color, title: String, description: String)] = [
        ("wand.and.stars", .teal, "Smart Paste", "Clean trackers and format text before pasting"),
        ("square.stack.3d.up", .indigo, "Paste Stack", "Queue clips and paste FIFO or LIFO"),
        ("text.quote", .mint, "Snippets", "Reusable templates with placeholders"),
        ("ruler", .yellow, "Clipboard Rules", "Normalize and clean copied content automatically"),
        ("lock.shield.fill", .red, "Privacy Controls", "Encryption and sensitive data protections")
    ]

    var body: some View {
        WorkflowListPageIOS(
            titlePrefix: "Advanced ",
            titleAccent: "Workflow",
            subtitle: "Power tools you configure once.",
            rows: steps,
            isIPad: isIPad
        )
    }
}

private struct WorkflowListPageIOS: View {
    let titlePrefix: String
    let titleAccent: String
    let subtitle: String
    let rows: [(icon: String, color: Color, title: String, description: String)]
    let isIPad: Bool

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isIPad ? 20 : 14) {
                    (Text(titlePrefix).foregroundStyle(.white) + Text(titleAccent).foregroundStyle(.teal))
                        .font(.system(size: isIPad ? 44 : 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text(subtitle)
                        .font(.system(size: isIPad ? 21 : 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: isIPad ? 720 : 320)

                    VStack(spacing: isIPad ? 16 : 10) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            FeatureRowIOS(
                                icon: row.icon,
                                color: row.color,
                                title: row.title,
                                description: row.description,
                                isIPad: isIPad
                            )
                        }
                    }
                    .frame(maxWidth: isIPad ? 760 : 340)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, isIPad ? 52 : 20)
                .padding(.top, isIPad ? 28 : 18)
                .padding(.bottom, isIPad ? 30 : 16)
            }
        }
    }
}

private struct FeatureRowIOS: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let isIPad: Bool

    var body: some View {
        HStack(spacing: isIPad ? 14 : 10) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 22 : 16))
                .foregroundStyle(color)
                .frame(width: isIPad ? 50 : 36, height: isIPad ? 50 : 36)
                .background(color.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: isIPad ? 12 : 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: isIPad ? 20 : 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: isIPad ? 17 : 13))
                    .foregroundStyle(.white.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, isIPad ? 14 : 10)
        .padding(.vertical, isIPad ? 10 : 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 14 : 10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Page 5: Sane Philosophy

private struct SanePhilosophyPageIOS: View {
    let isIPad: Bool

    var body: some View {
        VStack(spacing: isIPad ? 24 : 16) {
            Spacer(minLength: isIPad ? 24 : 14)

            Text("Our Sane Philosophy")
                .font(.system(size: isIPad ? 44 : 30, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: isIPad ? 8 : 6) {
                Text("\"For God has not given us a spirit of fear,")
                    .font(.system(size: isIPad ? 22 : 16))
                    .foregroundStyle(.white)
                Text("but of power and of love and of a sound mind.\"")
                    .font(.system(size: isIPad ? 22 : 16))
                    .foregroundStyle(.white)
                Text("— 2 Timothy 1:7")
                    .font(.system(size: isIPad ? 19 : 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, isIPad ? 60 : 16)

            HStack(alignment: .top, spacing: isIPad ? 16 : 8) {
                SanePillarCardIOS(
                    icon: "bolt.fill",
                    color: .yellow,
                    title: "Power",
                    lines: [
                        "Your data stays on your device.",
                        "100% transparent code.",
                        "Actively maintained."
                    ],
                    isIPad: isIPad
                )
                SanePillarCardIOS(
                    icon: "heart.fill",
                    color: .pink,
                    title: "Love",
                    lines: [
                        "Built to serve you.",
                        "Pay once, yours forever.",
                        "No subscriptions. No ads."
                    ],
                    isIPad: isIPad
                )
                SanePillarCardIOS(
                    icon: "brain.head.profile",
                    color: .teal,
                    title: "Sound Mind",
                    lines: [
                        "Calm and focused.",
                        "Does one thing well.",
                        "No clutter."
                    ],
                    isIPad: isIPad
                )
            }
            .padding(.horizontal, isIPad ? 50 : 8)

            Spacer(minLength: isIPad ? 24 : 12)
        }
    }
}

private struct SanePillarCardIOS: View {
    let icon: String
    let color: Color
    let title: String
    let lines: [String]
    let isIPad: Bool

    var body: some View {
        VStack(spacing: isIPad ? 10 : 7) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 30 : 22))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: isIPad ? 20 : 15, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: isIPad ? 6 : 4) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: isIPad ? 13 : 10, weight: .bold))
                            .foregroundStyle(.green)
                            .frame(width: isIPad ? 16 : 12)
                            .padding(.top, 2)
                        Text(line)
                            .font(.system(size: isIPad ? 15 : 12))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.vertical, isIPad ? 18 : 12)
        .padding(.horizontal, isIPad ? 12 : 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 18 : 12))
    }
}

// MARK: - Page 6: Permissions

private struct PermissionsPageIOS: View {
    let isIPad: Bool

    var body: some View {
        VStack(spacing: isIPad ? 22 : 16) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: isIPad ? 62 : 44))
                .foregroundStyle(.teal)

            Text("Permissions")
                .font(.system(size: isIPad ? 46 : 30, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: isIPad ? 12 : 10) {
                permissionRow(icon: "video.slash.fill", text: "No screen recording needed.", isIPad: isIPad)
                permissionRow(icon: "eye.slash.fill", text: "No screenshots collected.", isIPad: isIPad)
                permissionRow(icon: "icloud.slash", text: "No data sold. You control sync.", isIPad: isIPad)
            }
            .padding(.horizontal, isIPad ? 90 : 24)

            Text("Enable only what you need in iOS Settings.")
                .font(.system(size: isIPad ? 19 : 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 100 : 24)

            Spacer()
        }
    }

    private func permissionRow(icon: String, text: String, isIPad: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 20 : 16))
                .foregroundStyle(.teal)
                .frame(width: isIPad ? 28 : 22)
            Text(text)
                .font(.system(size: isIPad ? 19 : 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 12 : 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 14 : 10))
    }
}

// MARK: - Page 7: Plan / Upgrade

private struct PlanUpgradePageIOS: View {
    let isIPad: Bool

    var body: some View {
        VStack(spacing: isIPad ? 20 : 14) {
            Spacer(minLength: isIPad ? 24 : 16)

            (Text("Choose ").foregroundStyle(.white) + Text("Your Plan").foregroundStyle(.teal))
                .font(.system(size: isIPad ? 44 : 30, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: isIPad ? 18 : 10) {
                planCard(
                    title: "Basic",
                    subtitle: "$0",
                    lines: [
                        "Clipboard history (50 items)",
                        "Search and source filters",
                        "iCloud sync + iPhone/iPad app"
                    ],
                    accent: .white
                )

                planCard(
                    title: "Pro",
                    subtitle: "One-time unlock",
                    lines: [
                        "Paste Stack + Snippets",
                        "Clipboard Rules + Item Notes",
                        "Touch ID lock + encryption"
                    ],
                    accent: .teal
                )
            }
            .padding(.horizontal, isIPad ? 60 : 12)

            Text("You can start free and upgrade later.")
                .font(.system(size: isIPad ? 19 : 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 80 : 22)

            Spacer(minLength: isIPad ? 18 : 10)
        }
    }

    private func planCard(title: String, subtitle: String, lines: [String], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: isIPad ? 10 : 8) {
            Text(title)
                .font(.system(size: isIPad ? 24 : 18, weight: .bold))
                .foregroundStyle(accent)

            Text(subtitle)
                .font(.system(size: isIPad ? 16 : 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Divider().overlay(Color.white.opacity(0.25))

            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: isIPad ? 12 : 10, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.top, 3)
                    Text(line)
                        .font(.system(size: isIPad ? 15 : 12))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(isIPad ? 16 : 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 16 : 12))
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
