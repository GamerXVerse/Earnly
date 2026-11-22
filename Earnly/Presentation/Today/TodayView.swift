import SwiftUI

/// Today: the most important state first. The hero is either a platform measurement or an
/// honest statement of what is configured; it is never an invented countdown.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        let state = model.dashboard
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if let hero = state.hero {
                        HeroBlock(hero: hero, progress: state.progressFraction, tone: state.tone)
                            .padding(.top, EarnlySpacing.xl)
                    }
                    statusBlock(state)
                        .padding(.top, EarnlySpacing.lg)
                    if let primary = state.primary {
                        EarnlyButton(title: primary.title, trailingSymbol: symbol(for: primary.action)) {
                            perform(primary.action)
                        }
                        .disabled(model.isRetrying)
                        .padding(.top, EarnlySpacing.lg)
                    }
                    if state.state == .authorizationRecovery {
                        Text("Practice sessions open when your selected apps are restricted, which needs Screen Time access.")
                            .font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
                            .padding(.top, EarnlySpacing.sm)
                    }

                    section { StudyActivitySection(earned: model.snapshot?.earnedMinutes, onTap: { router.select(.progress) }) }
                    section { ExamRow(profile: model.profile, onTap: { router.select(.practice) }) }
                    section { ConfigurationRow(policy: model.policy, status: model.monitoringStatus, onTap: { router.open(.screenTime) }) }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.bottom, EarnlySpacing.xl)
                .earnlyAnimation(EarnlyMotion.standard, value: state.state)
            }
            .background(EarnlyColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            EarnlyWordmark(size: 28)
            if model.isSimulated { EarnlyPreviewTag(text: "Simulated").padding(.leading, EarnlySpacing.xs) }
            Spacer()
            Button { router.select(.settings) } label: {
                Image(systemName: "gearshape").font(.body).foregroundStyle(EarnlyColor.ink)
                    .frame(width: EarnlyGeometry.minTouchTarget, height: EarnlyGeometry.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, EarnlySpacing.xxs)
    }

    @ViewBuilder
    private func statusBlock(_ state: DashboardPresentation) -> some View {
        switch state.tone {
        case .neutral:
            VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                Text(state.title).font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
                    .accessibilityAddTraits(.isHeader)
                if !state.detail.isEmpty {
                    Text(state.detail).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                }
            }
        case .success:
            EarnlyStatusMessage(kind: .success, title: state.title, text: state.detail)
        case .warning:
            EarnlyStatusMessage(kind: .warning, title: state.title, text: state.detail)
        }
    }

    private func symbol(for action: DashboardPresentation.Action) -> String? {
        switch action {
        case .retryOperation, .retryRelease: return nil
        default: return "arrow.right"
        }
    }

    private func perform(_ action: DashboardPresentation.Action) {
        switch action {
        case .allowAccess, .reviewAccess: router.open(.permissions)
        case .chooseApps: router.open(.activities)
        case .startPractice, .resumePractice: router.startPractice()
        case .retryOperation, .retryRelease: Task { await model.retryPendingOperation() }
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

private struct HeroBlock: View {
    let hero: DashboardPresentation.Hero
    let progress: Double?
    let tone: DashboardPresentation.Tone

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
            Text(hero.overline).earnlyOverline()
            Text(hero.value)
                .earnlyHeroNumber()
                .foregroundStyle(EarnlyColor.ink)
                .contentTransition(.numericText())
            if let progress {
                EarnlyProgressBar(value: progress, tone: tone == .success ? .success : .brand,
                                  accessibilityLabel: "Session progress")
                    .padding(.top, EarnlySpacing.xxs)
            }
            Text(hero.caption).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StudyActivitySection: View {
    let earned: Int?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.md) {
            EarnlySectionHeader("Your study activity")
            if let earned, earned > 0 {
                VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                    Text("\(earned)m").font(EarnlyFont.stat).foregroundStyle(EarnlyColor.ink)
                    Text("Time earned in total").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("No practice yet. Your first set will show up here.")
                    .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
            }
        }
        .accessibilityElement(children: .contain)
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
    let policy: PolicySummary
    let status: MonitoringStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                    Text("Screen-time rules").font(EarnlyFont.secondaryEmphasis).foregroundStyle(EarnlyColor.ink)
                    Text("\(policy.allowanceMinutes)-minute allowance · \(policy.requiredQuestions) questions = \(policy.rewardMinutes) minutes")
                        .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                    Text(status.text).font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
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

#if DEBUG
@MainActor private func previewToday(_ fixture: DevelopmentFixture) -> some View {
    let model = AppModel(service: DevelopmentScreenTimeService(fixture: fixture, latency: .zero), profile: .sample, hasCompletedOnboarding: true, defaults: nil)
    return TodayView().environment(model).environment(AppRouter()).task { await model.refreshSnapshot() }
}
#Preview("Today: allowance active") { previewToday(.allowanceActive) }
#Preview("Today: restricted") { previewToday(.thresholdReached) }
#Preview("Today: release failed") { previewToday(.releaseFailure) }
#Preview("Today: authorization denied") { previewToday(.authorizationDenied) }
#endif
