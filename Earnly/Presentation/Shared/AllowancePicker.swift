import SwiftUI

/// 10 or 15 minute allowance as full-width radio rows. Pure selection: the caller decides
/// when the choice is applied (onboarding applies at once, Settings applies on Save).
struct AllowancePicker: View {
    @Binding var selection: Int
    var isDisabled = false

    var body: some View {
        VStack(spacing: EarnlySpacing.sm) {
            ForEach(PolicySummary.allowanceOptions, id: \.self) { minutes in
                EarnlySelectionRow(
                    title: "\(minutes) minutes", isSelected: selection == minutes, indicator: .radio
                ) { selection = minutes }
                .disabled(isDisabled)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Allowance")
    }
}

/// Pending or failed state of an allowance change.
struct AllowanceChangeStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.change {
        case .idle: EmptyView()
        case .applying(let text):
            Text("\(text)…").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        case .failed(let failure):
            EarnlyStatusMessage(kind: .warning, title: "Allowance not changed", text: failure.userMessage)
        }
    }
}

/// Reward rule from policy. Questions and minutes are separate values.
struct RewardRuleSummary: View {
    let policy: PolicySummary

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
            Text("Your reward").earnlyOverline()
            Text("\(policy.requiredQuestions) questions = \(policy.rewardMinutes) minutes")
                .font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(policy.requiredQuestions) questions earn \(policy.rewardMinutes) minutes")
    }
}
