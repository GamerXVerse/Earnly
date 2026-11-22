import SwiftUI

/// Why Earnly asks, plus the state-specific status and action. Shared by onboarding and Settings.
struct AuthorizationExplainer: View {
    private let points: [(title: String, detail: String)] = [
        ("You choose the apps", "Earnly manages only the apps, categories and websites you pick."),
        ("Apple does the monitoring", "Earnly uses Apple's Screen Time to track the entertainment time you configure, and to restrict your selected apps once your allowance is used."),
        ("You stay in control", "You set this up yourself, so you can also turn it off in iOS Settings at any time."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
            ForEach(points, id: \.title) { point in
                VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                    Text(point.title).font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
                    Text(point.detail).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Authorization state as a message. Never shows success unless the service confirmed it.
struct AuthorizationStatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.authorization {
        case .notRequested:
            Text("Permission not requested yet.").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        case .requesting:
            Text("Waiting for your response…").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        case .authorized:
            EarnlyStatusMessage(kind: .success, title: "Screen Time access is on",
                                text: "Apple confirmed access. Next, choose which apps Earnly manages.")
        case .denied:
            EarnlyStatusMessage(kind: .warning, title: "Access declined",
                                text: "Earnly won't ask again. To allow it, turn on Screen Time access for Earnly in iOS Settings. You can still use the app without it.")
        case .revoked:
            EarnlyStatusMessage(kind: .warning, title: "Access was turned off",
                                text: "Earnly stopped managing your apps. Turn access back on in iOS Settings, then choose your apps again.")
        case .unavailable:
            EarnlyStatusMessage(kind: .warning, title: "Screen Time isn't available",
                                text: "This device can't offer Screen Time access right now, for example because Screen Time is restricted.")
        case .failed(let message):
            EarnlyStatusMessage(kind: .warning, title: "Something went wrong", text: message)
        }
        if model.isSimulated {
            EarnlyStatusMessage(kind: .development, title: "Simulated",
                                text: "Development build: this result comes from a test adapter, not Apple's Screen Time.")
        }
    }
}

/// Primary action for the current authorization state. A decided state offers iOS Settings,
/// never another system prompt.
struct AuthorizationAction: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch model.authorization {
        case .notRequested:
            EarnlyButton(title: "Allow Screen Time access") {
                EarnlyHaptics.light()
                Task { await model.requestAuthorization() }
            }
        case .requesting:
            EarnlyButton(title: "Waiting for Apple…") {}.disabled(true)
        case .failed:
            EarnlyButton(title: "Try again") {
                model.clearAuthorizationError()
                Task { await model.requestAuthorization() }
            }
        case .denied, .revoked:
            EarnlyButton(title: "Open iOS Settings", kind: .secondary) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        case .unavailable, .authorized:
            EmptyView()
        }
    }
}
