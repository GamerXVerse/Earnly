import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PreviewAppModel.self) private var model

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
        .fullScreenCover(item: $router.practiceLaunch) { launch in
            PracticeSessionView(
                session: PreviewPracticeSession(rewardMinutes: model.profile.rewardMinutes, startingAt: launch.startingAt),
                onClose: { router.dismissPractice() },
                onFinish: {
                    model.finishPractice()
                    router.dismissPractice()
                    router.select(.today)
                })
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppRouter())
        .environment(PreviewAppModel.previewMain)
}
