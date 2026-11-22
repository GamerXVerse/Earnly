import SwiftUI

/// Today: the allowance is the focal point, then the primary action, then
/// flat supporting sections separated by rules.
struct TodayView: View {
    @Environment(PreviewAppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        let state = model.restriction
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    AllowanceSummary(state: state)
                        .padding(.top, EarnlySpacing.xl)
                    statusBlock(state)
                        .padding(.top, EarnlySpacing.lg)
                    actions(state)
                        .padding(.top, EarnlySpacing.lg)

                    section { StudyActivitySection(state: state, onTap: { router.select(.progress) }) }
                    section { ExamRow(profile: model.profile, onTap: { router.select(.practice) }) }
                    section { ConfigurationRow(profile: model.profile, onTap: { router.open(.screenTime) }) }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.bottom, EarnlySpacing.xl)
            }
            .background(EarnlyColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            EarnlyWordmark(size: 28)
            Spacer()
            Button {
                router.select(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(EarnlyColor.ink)
                    .frame(width: EarnlyGeometry.minTouchTarget, height: EarnlyGeometry.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, EarnlySpacing.xxs)
    }

    @ViewBuilder
    private func statusBlock(_ state: PreviewRestrictionState) -> some View {
        switch state.tone {
        case .neutral:
            VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                Text(state.statusTitle).font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
                Text(state.statusDetail).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                if let progress = state.sessionProgress {
                    Text(progress).font(EarnlyFont.secondaryEmphasis.monospacedDigit()).foregroundStyle(EarnlyColor.brandText)
                }
            }
        case .success:
            EarnlyStatusMessage(kind: .success, title: state.statusTitle, text: state.statusDetail)
        case .warning:
            EarnlyStatusMessage(kind: .warning, title: state.statusTitle, text: state.statusDetail)
        }
    }

    @ViewBuilder
    private func actions(_ state: PreviewRestrictionState) -> some View {
        VStack(spacing: EarnlySpacing.xs) {
            EarnlyButton(title: state.primaryTitle, trailingSymbol: "arrow.right") {
                perform(state.primaryAction)
            }
            if let secondary = state.secondaryPracticeTitle {
                EarnlyButton(title: secondary, kind: .secondary) { router.startPractice() }
            }
        }
    }

    private func perform(_ action: PreviewRestrictionState.PrimaryAction) {
        switch action {
        case .finishSetup: model.restartOnboarding()
        case .startPractice: router.startPractice()
        case .resumePractice: router.startPractice(startingAt: 3)
        case .reviewPermission: router.open(.permissions)
        }
    }

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EarnlyDivider().padding(.vertical, EarnlySpacing.lg)
            content()
        }
        .padding(.top, EarnlySpacing.xs)
    }
}

/// Hero allowance display. `--:--` is shown whenever remaining time is unknown.
struct AllowanceSummary: View {
    let state: PreviewRestrictionState

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
            HStack {
                Text("Available screen time").earnlyOverline()
                Spacer()
                EarnlyPreviewTag()
            }
            Text(state.remainingText)
                .earnlyHeroNumber()
                .foregroundStyle(state.remainingSeconds == nil ? EarnlyColor.inkSecondary : EarnlyColor.ink)
                .contentTransition(.numericText())
                .accessibilityLabel(state.accessibilityRemaining)
            EarnlyProgressBar(
                value: state.remainingFraction,
                tone: state.tone == .success ? .success : .brand,
                accessibilityLabel: "Allowance remaining")
                .padding(.top, EarnlySpacing.xxs)
            Text(caption)
                .font(EarnlyFont.secondary)
                .foregroundStyle(EarnlyColor.inkSecondary)
        }
        .accessibilityElement(children: .contain)
    }

    private var caption: String {
        state.remainingSeconds == nil
            ? "Remaining time isn't available right now."
            : "of your \(state.allowanceSeconds / 60)-minute allowance. Sample value; updates when you open Earnly."
    }
}

private struct StudyActivitySection: View {
    let state: PreviewRestrictionState
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.md) {
            EarnlySectionHeader("Your study activity")
            if let questions = state.questionsToday {
                HStack(alignment: .top, spacing: EarnlySpacing.xl) {
                    stat("\(questions)", "Questions")
                    stat(state.minutesEarnedToday.map { "\($0)m" } ?? "--", "Time earned")
                    Spacer(minLength: 0)
                }
            } else {
                Text("No practice yet. Your first set will show up here.")
                    .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
            Text(value).font(EarnlyFont.stat).foregroundStyle(EarnlyColor.ink)
            Text(label).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExamRow: View {
    let profile: PreviewStudyProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                    Text(profile.primaryExamTitle).font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
                    Text(profile.primaryExamSubtitle).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.body.weight(.medium)).foregroundStyle(EarnlyColor.inkSecondary)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .frame(minHeight: EarnlyGeometry.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Practice")
    }
}

private struct ConfigurationRow: View {
    let profile: PreviewStudyProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                    Text("Screen-time rules").font(EarnlyFont.secondaryEmphasis).foregroundStyle(EarnlyColor.ink)
                    Text(profile.configurationSummary).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.body.weight(.medium)).foregroundStyle(EarnlyColor.inkSecondary)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .frame(minHeight: EarnlyGeometry.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens screen-time settings")
    }
}

#Preview("Today: available") {
    TodayView()
        .environment(PreviewAppModel.previewMain)
        .environment(AppRouter())
}

#Preview("Today: practice required") {
    let model = PreviewAppModel.previewMain
    model.dashboardState = .practiceRequired
    return TodayView().environment(model).environment(AppRouter())
}

#Preview("Today: first launch") {
    let model = PreviewAppModel.previewMain
    model.dashboardState = .firstLaunchIncomplete
    return TodayView().environment(model).environment(AppRouter())
}

#Preview("Today: authorization unavailable") {
    let model = PreviewAppModel.previewMain
    model.dashboardState = .authorizationUnavailable
    return TodayView().environment(model).environment(AppRouter())
}

#Preview("Today: earned, dark") {
    let model = PreviewAppModel.previewMain
    model.dashboardState = .earned
    return TodayView().environment(model).environment(AppRouter()).preferredColorScheme(.dark)
}
