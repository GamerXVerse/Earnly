import SwiftUI

struct SettingsView: View {
    @Environment(PreviewAppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.settingsPath) {
            List {
                Section("Exam preferences") {
                    row("Exams", value: model.profile.examSummary, route: .exams)
                }
                Section("Screen time") {
                    row("Starting allowance", value: "\(model.profile.allowanceMinutes) min", route: .screenTime)
                }
                Section("Practice rewards") {
                    row("Reward rule", value: "\(model.profile.rewardQuestions) → \(model.profile.rewardMinutes) min", route: .rewards)
                }
                Section("Permissions") {
                    row("Screen Time access", value: model.authorization.shortLabel, route: .permissions)
                }
                Section("Accessibility") {
                    row("Text, motion, and contrast", value: nil, route: .accessibility)
                }
                Section("Privacy") {
                    row("How Earnly handles data", value: nil, route: .privacy)
                }
                Section("Application") {
                    row("About Earnly", value: "0.1.0", route: .about)
                }
                Section {
                    row("Development tools", value: nil, route: .development)
                } header: {
                    Text("Development")
                } footer: {
                    Text("Prototype controls. They are removed before release.")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(EarnlyColor.canvas)
            .navigationDestination(for: SettingsRoute.self) { route in
                destination(route)
            }
        }
    }

    private func row(_ title: String, value: String?, route: SettingsRoute) -> some View {
        NavigationLink(value: route) {
            HStack {
                Text(title).foregroundStyle(EarnlyColor.ink)
                if let value {
                    Spacer(minLength: EarnlySpacing.xs)
                    Text(value).foregroundStyle(EarnlyColor.inkSecondary).multilineTextAlignment(.trailing)
                }
            }
            .frame(minHeight: EarnlyGeometry.minTouchTarget)
        }
    }

    @ViewBuilder
    private func destination(_ route: SettingsRoute) -> some View {
        switch route {
        case .exams: ExamPreferencesView()
        case .screenTime: ScreenTimeSettingsView()
        case .rewards: RewardSettingsView()
        case .permissions: PermissionsView()
        case .accessibility: AccessibilitySettingsView()
        case .privacy: PrivacyView()
        case .about: AboutView()
        case .development: DevelopmentView()
        }
    }
}

extension PreviewAuthorizationState {
    var shortLabel: String {
        switch self {
        case .notDetermined: return "Not requested"
        case .simulatedGranted: return "Simulated"
        case .denied: return "Declined"
        case .unavailable: return "Unavailable"
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .environment(PreviewAppModel.previewMain)
        .environment(AppRouter())
}
