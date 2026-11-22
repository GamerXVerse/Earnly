import SwiftUI

/// Screen 5: why Earnly asks for Screen Time access, and the live authorization state.
struct AuthorizationStep: View {
    var body: some View {
        OnboardingPage(
            title: "Allow Screen Time access",
            subtitle: "Earnly needs Apple's Screen Time permission to pause the apps you choose when your allowance runs out."
        ) {
            VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                AuthorizationExplainer()
                EarnlyDivider()
                AuthorizationStatusView()
            }
        }
    }
}

#if DEBUG
#Preview("Authorization") {
    AuthorizationStep()
        .environment(AppModel(service: DevelopmentScreenTimeService(), defaults: nil))
        .background(EarnlyColor.canvas)
}
#endif
