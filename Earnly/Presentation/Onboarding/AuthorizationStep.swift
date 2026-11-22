import SwiftUI

/// Screen 5: why Earnly asks for Screen Time access, plus permission states.
/// Authorization is never reported as real in Phase 1; any "granted" result is a
/// labeled development simulation.
struct AuthorizationStep: View {
    @Environment(PreviewAppModel.self) private var model

    private let points: [(title: String, detail: String)] = [
        ("You choose the apps", "Pick the apps to pause, like YouTube or TikTok. Apple's picker keeps the selection private to your device."),
        ("Apple manages the restriction", "iOS applies the pause using its Screen Time system. Earnly doesn't see what you do in other apps."),
        ("You stay in control", "You can turn access off at any time in iOS Settings."),
    ]

    var body: some View {
        OnboardingPage(
            title: "Allow Screen Time access",
            subtitle: "Earnly needs Apple's Screen Time permission to pause the apps you choose when your allowance runs out."
        ) {
            VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                ForEach(points, id: \.title) { point in
                    VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                        Text(point.title).font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
                        Text(point.detail).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }

                EarnlyDivider()
                statusView
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.authorization {
        case .notDetermined:
            statusRow("Not yet allowed")
        case .simulatedGranted:
            EarnlyStatusMessage(
                kind: .development, title: "Development mode",
                text: "Access was simulated. No real Screen Time permission was granted and no apps are restricted.")
        case .denied:
            EarnlyStatusMessage(
                kind: .warning, title: "Access declined",
                text: "You can still practice, but Earnly can't pause your apps. You can allow access later in Settings.")
        case .unavailable:
            EarnlyStatusMessage(
                kind: .warning, title: "Screen Time unavailable",
                text: "This device can't offer Screen Time access right now. You can still practice.")
        }
        if model.authorization == .notDetermined {
            Button("Simulate declined (development)") { model.requestAuthorization(simulating: .denied) }
                .buttonStyle(.earnlyText)
                .font(EarnlyFont.caption)
        }
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: EarnlySpacing.xs) {
            Image(systemName: "lock").foregroundStyle(EarnlyColor.inkSecondary).accessibilityHidden(true)
            Text("Permission: \(text)").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        }
    }
}

#Preview("Authorization") {
    AuthorizationStep()
        .environment(PreviewAppModel())
        .background(EarnlyColor.canvas)
}
