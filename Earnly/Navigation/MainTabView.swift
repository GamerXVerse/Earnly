import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.symbol) }
                .tag(AppTab.today)
            PracticeHomeView()
                .tabItem { Label(AppTab.practice.title, systemImage: AppTab.practice.symbol) }
                .tag(AppTab.practice)
            ProgressOverviewView()
                .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.symbol) }
                .tag(AppTab.progress)
            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
        .tint(EarnlyColor.brand)
        .fullScreenCover(item: $router.practiceLaunch) { _ in
            PracticeSessionView(
                flow: PracticeFlowModel(app: model),
                onClose: { router.dismissPractice() },
                onFinish: {
                    router.dismissPractice()
                    router.select(.today)
                })
        }
    }
}

#if DEBUG
#Preview {
    MainTabView()
        .environment(AppRouter())
        .environment(AppModel(service: DevelopmentScreenTimeService(fixture: .allowanceActive), defaults: nil))
}
#endif
