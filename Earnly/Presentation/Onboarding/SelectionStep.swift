import SwiftUI

/// Screen 6: choose the apps Earnly manages, using the same panel as Settings.
struct SelectionStep: View {
    var body: some View {
        OnboardingPage(
            title: "Choose your distractions.",
            subtitle: "Select which apps Earnly should manage using Apple's Screen Time controls.",
            overline: "Screen Time"
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
