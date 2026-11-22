import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.settingsPath) {
            List {
                Section("Exam preferences") {
                    row("Exams", value: model.profile.examSummary, route: .exams)
                }
                Section("Screen Time") {
                    row("Screen Time access", value: accessLabel, route: .permissions)
                    row("Selected apps", value: selectionLabel, route: .activities)
                    row("Allowance", value: "\(model.policy.allowanceMinutes) min", route: .screenTime)
                    row("Reward rule", value: "\(model.policy.requiredQuestions) → \(model.policy.rewardMinutes) min", route: .rewards)
                    row("Monitoring", value: model.monitoringStatus.text, route: .monitoring)
                }
                Section("Accessibility") {
                    row("Text, motion, and contrast", value: nil, route: .accessibility)
                }
                Section("Privacy") {
                    row("How Earnly handles data", value: nil, route: .privacy)
                }
                Section("Application") {
                    row("About Earnly", value: "0.2.0", route: .about)
                }
                #if DEBUG
                Section {
                    row("Development tools", value: nil, route: .development)
                } header: {
                    Text("Development")
                } footer: {
                    Text("Debug builds only. Not part of the release app.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(EarnlyColor.canvas)
            .navigationDestination(for: SettingsRoute.self) { route in destination(route) }
        }
    }

    private var accessLabel: String {
        switch model.authorization {
        case .authorized: return "On"
        case .notRequested: return "Not requested"
        case .requesting: return "Waiting"
        case .denied: return "Declined"
        case .revoked: return "Turned off"
        case .unavailable: return "Unavailable"
        case .failed: return "Error"
        }
    }

    private var selectionLabel: String {
        guard let selection = model.snapshot?.selection, !selection.isEmpty else { return "None" }
        return selection.description
    }

    private func row(_ title: String, value: String?, route: SettingsRoute) -> some View {
        NavigationLink(value: route) {
            HStack {
                Text(title).foregroundStyle(EarnlyColor.ink)
                Spacer(minLength: EarnlySpacing.xs)
                if let value {
                    Text(value).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                        .multilineTextAlignment(.trailing)
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
        case .activities: ActivitySelectionSettingsView()
        case .rewards: RewardSettingsView()
        case .permissions: PermissionsView()
        case .monitoring: MonitoringControlsView()
        case .accessibility: AccessibilitySettingsView()
        case .privacy: PrivacyView()
        case .about: AboutView()
        #if DEBUG
        case .development: DevelopmentView()
        #endif
        }
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView()
        .environment(AppModel(service: DevelopmentScreenTimeService(fixture: .allowanceActive), profile: .sample, hasCompletedOnboarding: true, defaults: nil))
        .environment(AppRouter())
}
#endif
