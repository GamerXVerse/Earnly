import SwiftUI

@main
struct EarnlyApp: App {
    @State private var model = AppModel.forLaunch()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(router)
        }
    }
}

extension AppModel {
    /// Debug launch arguments for deterministic UI tests and screenshots:
    /// `-earnly-skip-onboarding`, `-earnly-fixture <DevelopmentFixture>`, `-earnly-no-latency`,
    /// `-earnly-fresh-defaults`. Release builds ignore them and use the disconnected service.
    @MainActor
    static func forLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel {
        let service = ScreenTimeServiceFactory.make(arguments: arguments)
        #if DEBUG
        let skip = arguments.contains("-earnly-skip-onboarding")
        let useDefaults = !arguments.contains("-earnly-fresh-defaults") && !skip
        return AppModel(
            service: service,
            profile: skip ? .sample : PreviewStudyProfile(),
            hasCompletedOnboarding: skip ? true : nil,
            defaults: useDefaults ? .standard : nil)
        #else
        return AppModel(service: service)
        #endif
    }
}
