import SwiftUI

private let devNote = "Exam choices aren't saved yet. They will be stored with your study profile."

struct ExamPreferencesView: View {
    @Environment(AppModel.self) private var model

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
    @Environment(AppModel.self) private var model
    @State private var draft: Int?

    private var chosen: Int { draft ?? model.policy.allowanceMinutes }
    private var isBusy: Bool { if case .applying = model.change { return true } else { return false } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                    Text("Screen Time").earnlyOverline().foregroundStyle(EarnlyColor.brandText)
                    Text("Make time work for you.").font(EarnlyFont.titleMedium).foregroundStyle(EarnlyColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Choose your entertainment allowance. It's what you can use before your selected apps pause, not a measure of time left.")
                        .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                AllowancePicker(selection: Binding(get: { chosen }, set: { draft = $0 }), isDisabled: isBusy)
                AllowanceChangeStatus()
                if model.snapshot?.stage == .configuring {
                    EarnlyStatusMessage(kind: .info, title: "Updating", text: "The new allowance is active once monitoring is confirmed.")
                }
                EarnlyDivider()
                RewardRuleSummary(policy: model.policy)
                EarnlyButton(title: isBusy ? "Saving…" : "Save allowance") {
                    Task { await model.setAllowance(minutes: chosen); draft = nil }
                }
                .disabled(isBusy || chosen == model.policy.allowanceMinutes)
            }
            .padding(EarnlySpacing.screenMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EarnlyColor.canvas)
        .navigationTitle("Allowance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ActivitySelectionSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                    Text("Screen Time").earnlyOverline().foregroundStyle(EarnlyColor.brandText)
                    Text("Choose your distractions.").font(EarnlyFont.titleMedium).foregroundStyle(EarnlyColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Select which apps Earnly should manage using Apple's Screen Time controls.")
                        .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                }
                ActivitySelectionPanel()
            }
            .padding(EarnlySpacing.screenMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EarnlyColor.canvas)
        .navigationTitle("Selected apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RewardSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                LabeledContent("Questions per set", value: "\(model.policy.requiredQuestions)")
                LabeledContent("Minutes earned", value: "\(model.policy.rewardMinutes)")
            } footer: {
                Text("The standard rule: finish the set to earn the minutes. These two values are set separately and can't be edited yet.")
            }
        }
        .navigationTitle("Reward rule")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}

struct PermissionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                AuthorizationExplainer()
                EarnlyDivider()
                AuthorizationStatusView()
                AuthorizationAction()
            }
            .padding(EarnlySpacing.screenMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EarnlyColor.canvas)
        .navigationTitle("Screen Time access")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Status and the supported way to turn Earnly's restrictions off.
struct MonitoringControlsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirming = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                let status = model.monitoringStatus
                EarnlyStatusMessage(
                    kind: status.kind == .on ? .success : (status.kind == .pending ? .info : .warning),
                    title: "Status", text: status.text)

                VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                    Text("Turn off restrictions").font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
                    Text("Removes Earnly's restrictions and stops monitoring. Your earned time and history are kept. To turn Earnly back on, you'll choose your apps again.")
                        .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                changeStatus

                EarnlyButton(title: "Turn off restrictions", kind: .secondary) { confirming = true }
                    .disabled(!canDisable)
            }
            .padding(EarnlySpacing.screenMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EarnlyColor.canvas)
        .navigationTitle("Monitoring")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Turn off Earnly's restrictions?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Turn off restrictions", role: .destructive) { Task { await model.disableRestrictions() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your selected apps will no longer be restricted by Earnly.")
        }
    }

    private var canDisable: Bool {
        if case .applying = model.change { return false }
        return model.snapshot?.selection != nil
    }

    @ViewBuilder
    private var changeStatus: some View {
        switch model.change {
        case .idle: EmptyView()
        case .applying(let text): Text("\(text)…").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        case .failed(let failure):
            EarnlyStatusMessage(kind: .warning, title: "Restrictions are still on", text: failure.userMessage)
        }
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
                paragraph("What Earnly keeps", "Earnly keeps your practice history and settings on this device. Your app selection is stored by Apple and isn't readable by Earnly.")
                paragraph("Screen Time and your apps", "Apple's Screen Time system manages restrictions on your device. Earnly doesn't see what you do in other apps.")
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
                LabeledContent("Version", value: "0.2.0")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(EarnlyColor.canvas)
    }
}

#if DEBUG
struct DevelopmentView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @State private var failRelease = false

    var body: some View {
        List {
            Section {
                EarnlyStatusMessage(kind: .development, title: "Simulated state",
                                    text: "These fixtures replace live state with deterministic test data. Nothing here reflects real Screen Time.")
                    .listRowInsets(.init()).listRowBackground(Color.clear)
            }
            Section("Fixtures") {
                ForEach(DevelopmentFixture.allCases) { fixture in
                    Button(fixture.title) {
                        Task {
                            await model.applyFixture(fixture)
                            router.select(.today)
                        }
                    }
                    .foregroundStyle(EarnlyColor.ink)
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
                }
            }
            Section {
                Toggle("Fail the next release", isOn: $failRelease)
                    .onChange(of: failRelease) { _, on in (model.service as? DevelopmentScreenTimeService)?.failNextRelease = on }
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
            } footer: { Text("The next shield release reports a failure, then succeeds on retry.") }
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
#endif
