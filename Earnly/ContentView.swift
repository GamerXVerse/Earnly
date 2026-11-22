import SwiftUI

/// Application shell: onboarding until complete, then the main tabs.
/// Reconciles with the systems layer at launch and whenever the app becomes active.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            EarnlyColor.canvas.ignoresSafeArea()
            if model.hasCompletedOnboarding {
                MainTabView().transition(.opacity)
            } else {
                OnboardingFlowView().transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : EarnlyMotion.emphasized, value: model.hasCompletedOnboarding)
        .task { await activate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await activate() } }
        }
    }

    private func activate() async {
        await model.reconcile()
        if model.hasCompletedOnboarding { router.routeOnActivation(model.snapshot) }
    }
}

#if DEBUG
#Preview("Shell") {
    ContentView()
        .environment(AppRouter())
        .environment(AppModel(service: DevelopmentScreenTimeService(), defaults: nil))
}
#endif
