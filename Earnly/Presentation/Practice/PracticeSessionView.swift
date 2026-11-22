import SwiftUI

/// Full-screen, distraction-free practice session.
/// The session object is temporary presentation state; production session
/// management belongs to the systems layer.
struct PracticeSessionView: View {
    @State var session: PreviewPracticeSession
    let onClose: () -> Void
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(session: PreviewPracticeSession, onClose: @escaping () -> Void, onFinish: @escaping () -> Void) {
        _session = State(initialValue: session)
        self.onClose = onClose
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            EarnlyColor.canvas.ignoresSafeArea()
            if session.phase == .completed {
                SessionCompleteView(session: session, onFinish: onFinish)
                    .transition(.opacity)
            } else {
                questionScreen
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : EarnlyMotion.standard, value: session.phase == .completed)
    }

    private var questionScreen: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                    Text(session.current.label).earnlyOverline()
                        .foregroundStyle(EarnlyColor.brandText)
                    QuestionStem(text: session.current.stem)
                    AnswerList(session: session)
                    if session.phase == .submitted {
                        AnswerFeedback(question: session.current, selected: session.selectedChoice ?? -1)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.top, EarnlySpacing.md)
                .padding(.bottom, EarnlySpacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id(session.index)
            footer
        }
        .earnlyAnimation(EarnlyMotion.quick, value: session.phase)
    }

    private var header: some View {
        VStack(spacing: EarnlySpacing.sm) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(EarnlyColor.ink)
                        .frame(width: EarnlyGeometry.minTouchTarget, height: EarnlyGeometry.minTouchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close practice")
                .accessibilityHint("Leaves this session. Progress isn't saved in the prototype.")
                Spacer()
                Text(session.progressText)
                    .font(EarnlyFont.secondary.monospacedDigit())
                    .foregroundStyle(EarnlyColor.inkSecondary)
                    .accessibilityLabel(session.progressText)
            }
            EarnlyProgressBar(value: session.progressFraction, accessibilityLabel: "Session progress")
        }
        .padding(.horizontal, EarnlySpacing.screenMargin)
        .padding(.top, EarnlySpacing.xxs)
    }

    private var footer: some View {
        VStack(spacing: EarnlySpacing.sm) {
            Label("\(session.rewardMinutes) minutes upon completion", systemImage: "clock")
                .font(EarnlyFont.secondary)
                .foregroundStyle(EarnlyColor.inkSecondary)
            switch session.phase {
            case .answering:
                EarnlyButton(title: "Check answer") {
                    session.submit()
                    session.isCorrect ? EarnlyHaptics.success() : EarnlyHaptics.warning()
                }
                .disabled(!session.canSubmit)
            default:
                EarnlyButton(title: session.isLastQuestion ? "Finish session" : "Next question",
                             trailingSymbol: "arrow.right") {
                    earnlyWithAnimation(reduceMotion: reduceMotion, EarnlyMotion.standard) { session.advance() }
                    if session.phase == .completed { EarnlyHaptics.success() }
                }
            }
        }
        .padding(.horizontal, EarnlySpacing.screenMargin)
        .padding(.top, EarnlySpacing.sm)
        .padding(.bottom, EarnlySpacing.md)
        .background(EarnlyColor.canvas)
    }
}

#Preview("Practice: answer selected") {
    let session = PreviewPracticeSession(startingAt: 3)
    session.select(1)
    return PracticeSessionView(session: session, onClose: {}, onFinish: {})
}

#Preview("Practice: incorrect with explanation") {
    let session = PreviewPracticeSession(startingAt: 3)
    session.select(0)
    session.submit()
    return PracticeSessionView(session: session, onClose: {}, onFinish: {})
}

#Preview("Practice: correct, dark") {
    let session = PreviewPracticeSession(startingAt: 3)
    session.select(1)
    session.submit()
    return PracticeSessionView(session: session, onClose: {}, onFinish: {}).preferredColorScheme(.dark)
}
