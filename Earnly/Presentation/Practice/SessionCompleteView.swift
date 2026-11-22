import SwiftUI

/// Completion. Centered mark, "Time earned.", minutes in brand purple, then a quiet summary.
/// The access line follows the systems layer: "Restoring access" until release is confirmed,
/// and a retry (never a repeat) if it fails. Mint appears only once access is restored.
struct SessionCompleteView: View {
    @Environment(AppModel.self) private var model
    let flow: PracticeFlowModel
    let onFinish: () -> Void

    var body: some View {
        let outcome = model.rewardOutcome
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: EarnlySpacing.md) {
                    EarnlyLogo(size: 56).padding(.top, EarnlySpacing.xxl)

                    Text(title).font(EarnlyFont.titleMedium).foregroundStyle(EarnlyColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    if let minutes = minutes(outcome) {
                        Text("+\(minutes) min").font(EarnlyFont.sectionHeading.monospacedDigit())
                            .foregroundStyle(EarnlyColor.brandText)
                    }
                    Text(subtitle(outcome)).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                        .multilineTextAlignment(.center)

                    if case .released = outcome {
                        Rectangle().fill(EarnlyColor.success).frame(width: 64, height: 6)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .accessibilityHidden(true)
                    }

                    statusMessage(outcome)

                    if let session = flow.session {
                        EarnlyDivider().padding(.vertical, EarnlySpacing.xs)
                        HStack(alignment: .top) {
                            summary("Completed", "\(session.answeredCount)/\(session.total)")
                            summary("Accuracy", session.total == 0 ? "--" : "\(Int((Double(session.correctCount) / Double(session.total) * 100).rounded()))%")
                        }
                    }

                    if model.isSimulated {
                        EarnlyStatusMessage(kind: .development, title: "Simulated",
                                            text: "Development build: no real allowance or restriction was changed.")
                    }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: EarnlySpacing.xs) {
                if case .releaseFailed = outcome {
                    EarnlyButton(title: model.isRetrying ? "Trying…" : "Try again") {
                        Task { await model.retryPendingOperation() }
                    }
                    .disabled(model.isRetrying)
                    EarnlyButton(title: "Back to Today", kind: .secondary, action: onFinish)
                } else if outcome == nil, model.rewardFailure != nil, let id = flow.session?.id {
                    EarnlyButton(title: "Try again") { Task { await model.completeReward(sessionID: id) } }
                    EarnlyButton(title: "Back to Today", kind: .secondary, action: onFinish)
                } else {
                    EarnlyButton(title: "Done", action: onFinish)
                }
            }
            .padding(.horizontal, EarnlySpacing.screenMargin)
            .padding(.top, EarnlySpacing.sm)
            .padding(.bottom, EarnlySpacing.md)
        }
        .earnlyAnimation(EarnlyMotion.standard, value: outcome)
        .onChange(of: outcome) { _, new in
            if case .released = new { EarnlyHaptics.success() }
        }
    }

    private var title: String {
        model.rewardOutcome == nil && model.rewardFailure != nil ? "Session complete." : "Time earned."
    }

    private func summary(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
            Text(label).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
            Text(value).font(EarnlyFont.stat).foregroundStyle(EarnlyColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func minutes(_ outcome: AppModel.RewardOutcome?) -> Int? {
        switch outcome {
        case .restoring(let m), .releaseFailed(let m), .released(let m): return m
        case .recording: return flow.session?.rewardMinutes
        case nil: return nil
        }
    }

    private func subtitle(_ outcome: AppModel.RewardOutcome?) -> String {
        switch outcome {
        case .recording: return "Recording your time."
        case .restoring: return "Restoring access. Your selected apps stay restricted until Earnly confirms it."
        case .releaseFailed: return "Access wasn't restored."
        case .released: return "Your selected apps are available again."
        case nil: return model.rewardFailure == nil ? "" : "Your time hasn't been recorded yet."
        }
    }

    @ViewBuilder
    private func statusMessage(_ outcome: AppModel.RewardOutcome?) -> some View {
        switch outcome {
        case .releaseFailed:
            EarnlyStatusMessage(kind: .warning, title: "Your reward is saved",
                                text: "Earnly couldn't lift the restriction. You don't need to answer the questions again. Try again, and it won't add the time twice.")
        case nil:
            if let failure = model.rewardFailure {
                EarnlyStatusMessage(kind: .warning, title: "Couldn't record your time", text: failure.userMessage)
            }
        default: EmptyView()
        }
    }
}
