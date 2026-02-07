@preconcurrency import ApplicationServices
import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            Group {
                switch currentPage {
                case 0:
                    WelcomePage()
                case 1:
                    PermissionsPage()
                case 2:
                    ShortcutsPage()
                case 3:
                    SanePromisePage()
                default:
                    WelcomePage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0 ..< 4) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(currentPage + 1) of 4")

            // Bottom Controls
            HStack {
                if currentPage < 3 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Skip setup and start using SaneClip immediately")

                    Spacer()

                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Continue to next setup step")
                } else {
                    Spacer()
                    Button("Start Using SaneClip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint("Complete setup and open SaneClip")
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 700, height: 520)
        .background(OnboardingBackground())
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        NSApp.keyWindow?.close()
    }
}

// MARK: - Background

struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color.clipBlue.opacity(0.08),
                    Color.purple.opacity(0.05),
                    Color.clipBlue.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Pages

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

            Text("Welcome to SaneClip")
                .font(.system(size: 32, weight: .bold))

            Text("The clipboard manager that stays out of your way.\nFast, private, and keyboard-centric.")
                .multilineTextAlignment(.center)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct PermissionsPage: View {
    @State private var isTrusted: Bool = AXIsProcessTrusted()
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 64))
                .foregroundStyle(isTrusted ? .green : .orange)

            Text("Permissions")
                .font(.system(size: 28, weight: .bold))

            VStack(spacing: 12) {
                Text("SaneClip needs Accessibility permissions to paste directly into other apps.")
                    .multilineTextAlignment(.center)
                    .font(.body)

                if isTrusted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Permissions granted!")
                    }
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Button("Grant Permissions") {
                        promptForPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("System Settings > Privacy & Security > Accessibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    isTrusted = AXIsProcessTrusted()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    @MainActor
    private func promptForPermissions() {
        // Prompt for accessibility permissions
        // Use nonisolated helper to avoid concurrency warnings
        requestAccessibilityPermission()
    }
}

// Helper function outside the view to avoid concurrency issues
private nonisolated func requestAccessibilityPermission() {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [key: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
}

struct ShortcutsPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("Master the Keyboard")
                .font(.system(size: 28, weight: .bold))

            VStack(spacing: 20) {
                ShortcutRow(
                    title: "Show History",
                    keys: ["⌘", "⇧", "V"],
                    description: "Opens the clipboard history at your cursor"
                )

                ShortcutRow(
                    title: "Paste Plain Text",
                    keys: ["⌘", "⇧", "⌥", "V"],
                    description: "Pastes the current item without formatting"
                )

                ShortcutRow(
                    title: "Quick Paste",
                    keys: ["⌘", "⌃", "1-9"],
                    description: "Instantly paste recent items"
                )
            }
            .padding(.horizontal)
        }
    }
}

struct ShortcutRow: View {
    let title: String
    let keys: [String]
    let description: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
        .frame(maxWidth: 500)
    }
}

// MARK: - Sane Promise (Brand Philosophy)

struct SanePromisePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Our Sane Philosophy")
                .font(.system(size: 32, weight: .bold))

            VStack(spacing: 8) {
                Text("\"For God has not given us a spirit of fear,")
                    .font(.system(size: 17))
                    .italic()
                Text("but of power and of love and of a sound mind.\"")
                    .font(.system(size: 17))
                    .italic()
                Text("— 2 Timothy 1:7")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }

            HStack(spacing: 20) {
                SanePillarCard(
                    icon: "bolt.fill",
                    color: .yellow,
                    title: "Power",
                    description: "Your data stays on your device. No cloud, no tracking."
                )

                SanePillarCard(
                    icon: "heart.fill",
                    color: .pink,
                    title: "Love",
                    description: "Built to serve you. No dark patterns or manipulation."
                )

                SanePillarCard(
                    icon: "brain.head.profile",
                    color: .purple,
                    title: "Sound Mind",
                    description: "Calm, focused design. No clutter or anxiety."
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .padding(32)
    }
}

private struct SanePillarCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 18, weight: .semibold))

            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Color.primary.opacity(0.08))
        .cornerRadius(12)
    }
}
