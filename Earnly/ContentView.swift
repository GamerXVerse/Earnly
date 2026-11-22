import SwiftUI

/// Application shell: onboarding until complete, then the main tabs.
struct ContentView: View {
    @Environment(PreviewAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            EarnlyColor.canvas.ignoresSafeArea()
            if model.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : EarnlyMotion.emphasized, value: model.hasCompletedOnboarding)
    }
}

#Preview("Shell") {
    ContentView()
        .environment(AppRouter())
        .environment(PreviewAppModel())
}
