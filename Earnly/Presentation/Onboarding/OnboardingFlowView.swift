import SwiftUI

/// Temporary navigation state for the five-step onboarding.
@Observable
final class OnboardingModel {
    static let stepCount = 5
    private(set) var step = 0
    private(set) var isMovingForward = true

    var isFirst: Bool { step == 0 }
    var isLast: Bool { step == OnboardingModel.stepCount - 1 }

    func next() {
        guard !isLast else { return }
        isMovingForward = true
        step += 1
    }

    func back() {
        guard !isFirst else { return }
        isMovingForward = false
        step -= 1
    }
}

struct OnboardingFlowView: View {
    @Environment(PreviewAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow = OnboardingModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                stepContent
                    .id(flow.step)
                    .transition(transition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            footer
        }
        .background(EarnlyColor.canvas.ignoresSafeArea())
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: flow.isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity)
    }

    private var header: some View {
        HStack(spacing: EarnlySpacing.sm) {
            Button {
                move { flow.back() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EarnlyColor.ink)
                    .frame(width: EarnlyGeometry.minTouchTarget, height: EarnlyGeometry.minTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .opacity(flow.isFirst ? 0 : 1)
            .frame(width: flow.isFirst ? 0 : EarnlyGeometry.minTouchTarget)
            .disabled(flow.isFirst)
            .accessibilityHidden(flow.isFirst)

            EarnlyStepIndicator(current: flow.step, total: OnboardingModel.stepCount)
        }
        .padding(.horizontal, EarnlySpacing.screenMargin)
        .padding(.top, EarnlySpacing.xxs)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case 0: IntroStep()
        case 1: HowItWorksStep()
        case 2: ExamSelectionStep()
        case 3: AllowanceStep()
        default: AuthorizationStep()
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: EarnlySpacing.xs) {
            switch flow.step {
            case 0:
                EarnlyButton(title: "Get started", trailingSymbol: "arrow.right") { move { flow.next() } }
            case 2:
                EarnlyButton(title: "Continue") { move { flow.next() } }
                    .disabled(model.profile.selectedExams.isEmpty)
                if model.profile.selectedExams.isEmpty {
                    Text("Select at least one exam to continue.")
                        .font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
                }
            case 4:
                authorizationFooter
            default:
                EarnlyButton(title: "Continue") { move { flow.next() } }
            }
        }
        .padding(.horizontal, EarnlySpacing.screenMargin)
        .padding(.top, EarnlySpacing.sm)
        .padding(.bottom, EarnlySpacing.md)
        .background(EarnlyColor.canvas)
    }

    @ViewBuilder
    private var authorizationFooter: some View {
        if model.authorization == .simulatedGranted {
            EarnlyButton(title: "Start using Earnly", trailingSymbol: "arrow.right") {
                EarnlyHaptics.success()
                model.completeOnboarding()
            }
        } else {
            EarnlyButton(title: model.authorization == .denied ? "Try again" : "Allow Screen Time access") {
                model.requestAuthorization()
                EarnlyHaptics.light()
            }
            EarnlyButton(title: "Continue without access", kind: .text) {
                model.completeOnboarding()
            }
        }
    }

    private func move(_ change: () -> Void) {
        earnlyWithAnimation(reduceMotion: reduceMotion, EarnlyMotion.emphasized, change)
    }
}

/// Shared scaffold for onboarding pages: title, optional subtitle, and content.
struct OnboardingPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                    Text(title)
                        .font(EarnlyFont.titleMedium)
                        .foregroundStyle(EarnlyColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(EarnlyFont.body)
                            .foregroundStyle(EarnlyColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content()
            }
            .padding(.horizontal, EarnlySpacing.screenMargin)
            .padding(.top, EarnlySpacing.xl)
            .padding(.bottom, EarnlySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview("Onboarding") {
    OnboardingFlowView()
        .environment(PreviewAppModel())
}
