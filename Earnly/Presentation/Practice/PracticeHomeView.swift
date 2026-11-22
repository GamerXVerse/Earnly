import SwiftUI

/// Practice tab. A session is available only when the systems layer reports selected apps as
/// restricted (or an unfinished session exists); the tab says so plainly otherwise.
struct PracticeHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        let state = model.dashboard
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                    Text("Practice")
                        .font(EarnlyFont.pageTitle).foregroundStyle(EarnlyColor.ink)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                        Text(headline(state)).earnlyOverline()
                        Text("\(model.policy.requiredQuestions) questions")
                            .font(EarnlyFont.titleMedium).foregroundStyle(EarnlyColor.ink)
                        Text(body(state))
                            .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if state.state == .restricted || state.state == .practiceInProgress, let primary = state.primary {
                        EarnlyButton(title: primary.title, trailingSymbol: "arrow.right") { router.startPractice() }
                    }

                    EarnlyDivider()

                    VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                        EarnlySectionHeader(title: "Preparing for") {
                            Button("Edit") { router.open(.exams) }
                                .font(EarnlyFont.secondaryEmphasis)
                                .foregroundStyle(EarnlyColor.brandText)
                                .frame(minHeight: EarnlyGeometry.minTouchTarget)
                        }
                        Text(model.profile.examSummary).font(EarnlyFont.body).foregroundStyle(EarnlyColor.ink)
                    }

                    if model.isSimulated {
                        EarnlyStatusMessage(kind: .development, title: "Simulated",
                                            text: "Development build with original sample questions. Real question sets arrive in a later phase.")
                    }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.top, EarnlySpacing.md)
                .padding(.bottom, EarnlySpacing.xl)
            }
            .background(EarnlyColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func headline(_ state: DashboardPresentation) -> String {
        switch state.state {
        case .practiceInProgress: return "Unfinished session"
        case .restricted: return "Ready when you are"
        default: return "Next set"
        }
    }

    private func body(_ state: DashboardPresentation) -> String {
        let p = model.policy
        switch state.state {
        case .practiceInProgress: return "Pick up where you left off. Finish the set to earn \(p.rewardMinutes) minutes."
        case .restricted: return "Finish the set to earn \(p.rewardMinutes) minutes of screen time."
        default: return "Sets open when your selected apps are restricted. Finish a set then to earn \(p.rewardMinutes) minutes."
        }
    }
}

#if DEBUG
#Preview("Practice home") {
    PracticeHomeView()
        .environment(AppModel(service: DevelopmentScreenTimeService(fixture: .thresholdReached), profile: .sample, hasCompletedOnboarding: true, defaults: nil))
        .environment(AppRouter())
}
#endif
