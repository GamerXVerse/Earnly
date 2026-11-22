import SwiftUI

/// Completion. Mint marks earned time only. The access message follows the systems layer:
/// "Restoring access" until release is confirmed, and a retry (never a repeat) if it fails.
struct SessionCompleteView: View {
    @Environment(AppModel.self) private var model
    let flow: PracticeFlowModel
    let onFinish: () -> Void

    var body: some View {
        let outcome = model.rewardOutcome
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                    EarnlyLogo(size: 56).padding(.top, EarnlySpacing.xxl)

                    VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                        Text(title(outcome))
                            .font(EarnlyFont.titleMedium)
                            .foregroundStyle(EarnlyColor.ink)
                            .accessibilityAddTraits(.isHeader)
                        if let session = flow.session {
                            Text("\(session.correctCount) of \(session.total) answered correctly")
                                .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                        }
                    }

                    if let minutes = minutes(outcome) {
                        VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                            Text("Time earned").earnlyOverline()
                            Text("+\(minutes) min").earnlyHeroNumber().foregroundStyle(EarnlyColor.ink)
                            if case .released = outcome {
                                Rectangle().fill(EarnlyColor.success).frame(height: 6)
                                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    statusMessage(outcome)
                    if model.isSimulated {
                        EarnlyStatusMessage(kind: .development, title: "Simulated",
                                            text: "Development build: no real allowance or restriction was changed.")
                    }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
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
                    EarnlyButton(title: "Back to Today", trailingSymbol: "arrow.right", action: onFinish)
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

    private func title(_ outcome: AppModel.RewardOutcome?) -> String {
        switch outcome {
        case .recording, .restoring: return "Time earned. Restoring access."
        case .releaseFailed: return "Time earned. Access wasn't restored."
        case .released: return "Your apps are available again."
        case nil: return model.rewardFailure == nil ? "Session complete" : "Session complete. Time not recorded."
        }
    }

    private func minutes(_ outcome: AppModel.RewardOutcome?) -> Int? {
        switch outcome {
        case .restoring(let m), .releaseFailed(let m), .released(let m): return m
        case .recording: return flow.session?.rewardMinutes
        case nil: return nil
        }
    }

    @ViewBuilder
    private func statusMessage(_ outcome: AppModel.RewardOutcome?) -> some View {
        switch outcome {
        case .recording, .restoring:
            Text("Your selected apps stay restricted until Earnly confirms access is back.")
                .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        case .releaseFailed:
            EarnlyStatusMessage(kind: .warning, title: "Your reward is saved",
                                text: "Earnly couldn't lift the restriction. You don't need to answer the questions again. Try again, and it won't add the time twice.")
        case .released:
            EmptyView()
        case nil:
            if let failure = model.rewardFailure {
                EarnlyStatusMessage(kind: .warning, title: "Couldn't record your time", text: failure.userMessage)
            }
        }
    }
}
