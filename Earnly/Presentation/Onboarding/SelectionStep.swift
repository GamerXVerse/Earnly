import SwiftUI

/// Screen 6: choose the apps Earnly manages, using the same panel as Settings.
struct SelectionStep: View {
    var body: some View {
        OnboardingPage(
            title: "Choose what Earnly manages",
            subtitle: "Pick the distracting apps, categories or websites that should pause when your allowance is used."
        ) {
            ActivitySelectionPanel()
        }
    }
}

#if DEBUG
#Preview("Selection") {
    SelectionStep()
        .environment(AppModel(service: DevelopmentScreenTimeService(fixture: .selectionEmpty), defaults: nil))
        .background(EarnlyColor.canvas)
}
#endif
