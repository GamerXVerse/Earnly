import SwiftUI

@main
struct EarnlyApp: App {
    @State private var model = PreviewAppModel.initialForLaunch()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(router)
        }
    }
}

extension PreviewAppModel {
    /// Supports deterministic UI testing and screenshots via launch arguments:
    /// `-earnly-skip-onboarding` and `-earnly-state <PreviewDashboardState raw value>`.
    static func initialForLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> PreviewAppModel {
        guard arguments.contains("-earnly-skip-onboarding") else { return PreviewAppModel() }
        let model = PreviewAppModel.previewMain
        if let flag = arguments.firstIndex(of: "-earnly-state"), arguments.indices.contains(flag + 1),
           let state = PreviewDashboardState(rawValue: arguments[flag + 1]) {
            model.dashboardState = state
        }
        if arguments.contains("-earnly-empty-progress") { model.showsDemoProgress = false }
        return model
    }
}
