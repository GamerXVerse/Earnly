import SwiftUI

/// Full-screen practice session. Question progression, evaluation and completion come from
/// `PracticeFlowModel`, which reads them from the service. Saved progress resumes automatically.
struct PracticeSessionView: View {
    @State var flow: PracticeFlowModel
    let onClose: () -> Void
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(flow: PracticeFlowModel, onClose: @escaping () -> Void, onFinish: @escaping () -> Void) {
        _flow = State(initialValue: flow)
        self.onClose = onClose
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            EarnlyColor.canvas.ignoresSafeArea()
            switch flow.phase {
            case .loading:
                ProgressView().accessibilityLabel("Loading practice")
            case .failed(let failure):
                failureScreen(failure)
            case .answering, .submitted:
                questionScreen.transition(.opacity)
            case .completed:
                SessionCompleteView(flow: flow, onFinish: onFinish).transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : EarnlyMotion.standard, value: flow.phase == .completed)
        .task { await flow.load() }
    }

    private func failureScreen(_ failure: ServiceFailure) -> some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
            HStack { closeButton; Spacer() }
            Spacer()
            EarnlyStatusMessage(kind: .warning, title: "Practice isn't available", text: failure.userMessage)
            if failure != .practiceUnavailable {
                EarnlyButton(title: "Try again") { Task { await flow.retry() } }
            }
            EarnlyButton(title: "Back", kind: .secondary, action: onClose)
            Spacer()
        }
        .padding(.horizontal, EarnlySpacing.screenMargin)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(EarnlyColor.ink)
                .frame(width: EarnlyGeometry.minTouchTarget, height: EarnlyGeometry.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Close practice")
        .accessibilityHint("Leaves this session. Your progress is saved.")
    }

    @ViewBuilder
    private var questionScreen: some View {
        if let question = flow.current {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                        Text(question.label).earnlyOverline().foregroundStyle(EarnlyColor.brandText)
                        QuestionStem(text: question.stem)
                        AnswerList(flow: flow)
                        if flow.phase == .submitted, let attempt = flow.lastAttempt {
                            AnswerFeedback(question: question, attempt: attempt).transition(.opacity)
                        }
                    }
                    .padding(.horizontal, EarnlySpacing.screenMargin)
                    .padding(.top, EarnlySpacing.md)
                    .padding(.bottom, EarnlySpacing.md)
                }
                .scrollBounceBehavior(.basedOnSize)
                .id(question.id)
                footer
            }
            .earnlyAnimation(EarnlyMotion.quick, value: flow.phase)
        }
    }

    private var header: some View {
        VStack(spacing: EarnlySpacing.sm) {
            HStack {
                closeButton
                Spacer()
                Text(flow.progressText)
                    .font(EarnlyFont.secondary.monospacedDigit())
                    .foregroundStyle(EarnlyColor.inkSecondary)
            }
            EarnlyProgressBar(value: flow.progressFraction, accessibilityLabel: "Session progress")
        }
        .padding(.horizontal, EarnlySpacing.screenMargin)
        .padding(.top, EarnlySpacing.xxs)
    }

    private var footer: some View {
        VStack(spacing: EarnlySpacing.sm) {
            if let session = flow.session {
                Label("\(session.rewardMinutes) minutes upon completion", systemImage: "clock")
                    .font(EarnlyFont.secondary)
                    .foregroundStyle(EarnlyColor.inkSecondary)
            }
            switch flow.phase {
            case .submitted:
                EarnlyButton(title: flow.isLastQuestion ? "Finish session" : "Next question", trailingSymbol: "arrow.right") {
                    Task { await flow.advance() }
                }
            default:
                EarnlyButton(title: flow.isSubmitting ? "Checking…" : "Check answer") {
                    Task {
                        await flow.submit()
                        flow.lastAttempt?.isCorrect == true ? EarnlyHaptics.success() : EarnlyHaptics.light()
                    }
                }
                .disabled(!flow.canSubmit)
            }
        }
        .padding(.horizontal, EarnlySpacing.screenMargin)
        .padding(.top, EarnlySpacing.sm)
        .padding(.bottom, EarnlySpacing.md)
        .background(EarnlyColor.canvas)
    }
}

#if DEBUG
@MainActor private func previewFlow(_ fixture: DevelopmentFixture) -> PracticeFlowModel {
    let model = AppModel(service: DevelopmentScreenTimeService(fixture: fixture, latency: .zero), profile: .sample, hasCompletedOnboarding: true, defaults: nil)
    return PracticeFlowModel(app: model)
}
#Preview("Practice: resumed") {
    PracticeSessionView(flow: previewFlow(.interruptedPractice), onClose: {}, onFinish: {})
}
#Preview("Practice: resumed, dark") {
    PracticeSessionView(flow: previewFlow(.interruptedPractice), onClose: {}, onFinish: {}).preferredColorScheme(.dark)
}
#endif
