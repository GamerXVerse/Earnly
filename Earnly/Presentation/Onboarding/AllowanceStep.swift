import SwiftUI

/// Screen 4: starting allowance (10 or 15 minutes) and the reward rule from policy.
struct AllowanceStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        OnboardingPage(
            title: "Set your starting allowance",
            subtitle: "Time you can spend in your selected apps before they pause."
        ) {
            VStack(alignment: .leading, spacing: EarnlySpacing.xxl) {
                AllowancePicker()
                EarnlyDivider()
                VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                    EarnlySectionHeader("How you earn more")
                    RewardRuleSummary(policy: model.policy)
                    Text("This is the standard rule. Allowance is what you can use; it isn't a measure of time left.")
                        .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                }
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
