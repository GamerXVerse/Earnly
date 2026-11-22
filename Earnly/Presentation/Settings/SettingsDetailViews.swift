import SwiftUI

private let devNote = "Development only: changes last until you quit the app and aren't saved."

struct ExamPreferencesView: View {
    @Environment(PreviewAppModel.self) private var model

    var body: some View {
        List {
            Section {
                ForEach([PreviewExam.sat, .psat, .act]) { exam in
                    checkRow(exam.title, subtitle: exam.subtitle, selected: model.profile.selectedExams.contains(exam)) {
                        model.profile.toggle(exam)
                    }
                }
            }
            Section {
                ForEach(PreviewAPSubject.allCases) { subject in
                    checkRow(subject.rawValue, subtitle: nil, selected: model.profile.selectedAPSubjects.contains(subject)) {
                        model.profile.toggle(subject)
                    }
                }
            } header: { Text("AP exams") } footer: { Text(devNote) }
        }
        .navigationTitle("Exams")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }

    private func checkRow(_ title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            EarnlyHaptics.selection()
            action()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(EarnlyColor.ink)
                    if let subtitle { Text(subtitle).font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary) }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark").foregroundStyle(EarnlyColor.brandText).accessibilityHidden(true)
                }
            }
            .frame(minHeight: EarnlyGeometry.minTouchTarget)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

struct ScreenTimeSettingsView: View {
    @Environment(PreviewAppModel.self) private var model

    var body: some View {
        @Bindable var profile = model.profile
        List {
            Section {
                Picker("Starting allowance", selection: $profile.allowanceMinutes) {
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
                .pickerStyle(.inline)
            } footer: { Text(devNote) }
            Section {
                Text("App selection uses Apple's picker and is connected in Phase 2.")
                    .foregroundStyle(EarnlyColor.inkSecondary)
            } header: { Text("Selected apps") }
        }
        .navigationTitle("Screen time")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}

struct RewardSettingsView: View {
    @Environment(PreviewAppModel.self) private var model

    var body: some View {
        List {
            Section {
                LabeledContent("Questions per set", value: "\(model.profile.rewardQuestions)")
                LabeledContent("Minutes earned", value: "\(model.profile.rewardMinutes)")
            } footer: {
                Text("Fixed in this prototype. These values become configurable once the systems layer is connected.")
            }
        }
        .navigationTitle("Reward rule")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}

struct PermissionsView: View {
    @Environment(PreviewAppModel.self) private var model

    var body: some View {
        List {
            Section {
                LabeledContent("Screen Time access", value: model.authorization.label)
            }
            if model.authorization == .simulatedGranted {
                Section {
                    EarnlyStatusMessage(
                        kind: .development, title: "Development mode",
                        text: "Access is simulated. Earnly has no real Screen Time permission and restricts no apps.")
                        .listRowInsets(.init())
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                Button("Request access (development simulation)") { model.requestAuthorization() }
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
                Button("Simulate declined") { model.requestAuthorization(simulating: .denied) }
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
                Button("Reset to not requested", role: .destructive) { model.requestAuthorization(simulating: .notDetermined) }
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
            } header: {
                Text("Development")
            } footer: {
                Text("Real authorization is connected in Phase 2. You can also change it later in iOS Settings.")
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}

struct AccessibilitySettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        List {
            Section {
                LabeledContent("Text size", value: typeSize.isAccessibilitySize ? "Accessibility size" : "Standard")
                LabeledContent("Reduce Motion", value: reduceMotion ? "On" : "Off")
                LabeledContent("Contrast", value: contrast == .increased ? "Increased" : "Standard")
            } footer: {
                Text("Earnly follows your iOS settings. To change them, open Settings > Accessibility on your device.")
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                paragraph("This prototype stores nothing", "Your selections live in memory and disappear when the app closes. Nothing is sent anywhere.")
                paragraph("Screen Time and your apps", "When connected, Apple's Screen Time system will manage restrictions on your device. Earnly won't see the content of other apps.")
                paragraph("Full policy", "A complete privacy policy will be linked here before release.")
            }
            .padding(EarnlySpacing.screenMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EarnlyColor.canvas)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func paragraph(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
            Text(title).font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
            Text(text).font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                    EarnlyLockup(markSize: 44, wordmarkSize: 34)
                    Text("Your screen time. Earned.").font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                }
                .padding(.vertical, EarnlySpacing.xs)
            }
            Section {
                LabeledContent("Version", value: "0.1.0 (Phase 1 prototype)")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}

struct DevelopmentView: View {
    @Environment(PreviewAppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                Picker("Today state", selection: $model.dashboardState) {
                    ForEach(PreviewDashboardState.allCases) { state in
                        Text(state.title).tag(state)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Today dashboard state")
            } footer: {
                Text("Overrides the Today screen with deterministic sample data.")
            }
            Section {
                Toggle("Show demo progress data", isOn: $model.showsDemoProgress)
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
            } footer: {
                Text("Turn off to see the empty Progress state.")
            }
            Section {
                Button("Restart onboarding", role: .destructive) { model.restartOnboarding() }
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
            }
        }
        .navigationTitle("Development")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}
