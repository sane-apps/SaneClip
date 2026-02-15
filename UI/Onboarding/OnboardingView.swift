@preconcurrency import ApplicationServices
import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showPermissionWarning = false
    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            Group {
                switch currentPage {
                case 0:
                    WelcomePage()
                case 1:
                    HowItWorksPage()
                case 2:
                    PermissionsPage()
                case 3:
                    SanePromisePage()
                default:
                    WelcomePage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0 ..< totalPages, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")

            // Bottom Controls
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.system(size: 14))
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        if currentPage == 2, !AXIsProcessTrusted() {
                            showPermissionWarning = true
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Using SaneClip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 700, height: 520)
        .background(OnboardingBackground())
        .alert(
            "Paste Won't Work Without Permission",
            isPresented: $showPermissionWarning
        ) {
            Button("Grant Permission") {
                requestAccessibilityPermission()
            }
            .keyboardShortcut(.defaultAction)
            Button("Continue Anyway", role: .destructive) {
                withAnimation { currentPage += 1 }
            }
        } message: {
            Text("SaneClip needs Accessibility permission to paste into apps. Without it, you can browse and copy your clipboard history, but paste won't work.")
        }
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

// MARK: - Page 0: Welcome

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

            Text("Welcome to SaneClip")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Text("Everything you copy is automatically saved.")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.9))

            // Visual: copy flow
            HStack(spacing: 16) {
                CopyFlowStep(icon: "doc.on.clipboard", label: "Copy anything")
                Image(systemName: "arrow.right")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.4))
                CopyFlowStep(icon: "clock.arrow.circlepath", label: "Saved to history")
                Image(systemName: "arrow.right")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.4))
                CopyFlowStep(icon: "text.cursor", label: "Paste anywhere")
            }
            .padding(.top, 8)

            Text("Text, images, files — SaneClip remembers it all.\nPrivate and local. Nothing leaves your Mac.")
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)
        }
        .padding()
    }
}

private struct CopyFlowStep: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Page 1: How It Works

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("How to Use SaneClip")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            // Access methods
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "menubar.arrow.up.rectangle",
                    title: "Click the menu bar icon",
                    description: "Your full clipboard history in a popover"
                )

                FeatureRow(
                    icon: "command",
                    title: "Press  \u{2318}\u{21E7}V",
                    description: "Open history from anywhere with one shortcut"
                )

                FeatureRow(
                    icon: "pin.fill",
                    title: "Pin important items",
                    description: "Right-click any item to pin it — stays at the top forever"
                )

                FeatureRow(
                    icon: "magnifyingglass",
                    title: "Search your history",
                    description: "Type to instantly filter — find anything you've copied"
                )

                FeatureRow(
                    icon: "text.quote",
                    title: "Snippets",
                    description: "Save templates with placeholders for repeated text"
                )
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 16)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()
        }
        .frame(maxWidth: 460)
    }
}

// MARK: - Page 2: Permissions

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
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                Text("SaneClip needs Accessibility permission to paste directly into other apps.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))

                if isTrusted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Permissions granted!")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                } else {
                    Button("Grant Permissions") {
                        requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Opens System Settings > Accessibility")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
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
}

// Open System Settings > Accessibility directly (same as SaneBar)
private nonisolated func requestAccessibilityPermission() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Page 3: Sane Promise (Brand Philosophy)

struct SanePromisePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Our Sane Philosophy")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("\"For God has not given us a spirit of fear,")
                    .font(.system(size: 17))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                Text("but of power and of love and of a sound mind.\"")
                    .font(.system(size: 17))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                Text("— 2 Timothy 1:7")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
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
                .foregroundStyle(.white)

            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}
