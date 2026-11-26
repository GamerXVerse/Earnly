import SwiftUI

/// Screen 4: starting allowance and the reward rule from policy.
struct AllowanceStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        OnboardingPage(
            title: "Make time work for you.",
            subtitle: "Choose your initial entertainment allowance.",
            overline: "Screen Time"
        ) {
            VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                AllowancePicker(
                    selection: Binding(
                        get: { model.displayedAllowance },
                        set: { minutes in Task { await model.setAllowance(minutes: minutes) } }),
                    isDisabled: { if case .applying = model.change { return true } else { return false } }())
                AllowanceChangeStatus()
                EarnlyDivider()
                RewardRuleSummary(policy: model.policy)
            }
        }
    }
}

#if DEBUG
#Preview("Allowance") {
    AllowanceStep()
        .environment(AppModel(service: DevelopmentScreenTimeService(), defaults: nil))
        .background(EarnlyColor.canvas)
}
#endif
