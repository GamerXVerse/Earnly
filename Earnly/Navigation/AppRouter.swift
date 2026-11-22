import Foundation
import Observation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case today, practice, progress, settings

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .today: return "house"
        case .practice: return "book"
        case .progress: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

enum SettingsRoute: Hashable {
    case exams, screenTime, rewards, permissions, accessibility, privacy, about, development
}

struct PracticeLaunch: Identifiable, Equatable {
    let id = UUID()
    var startingAt: Int
}

/// Focused navigation state: tab selection, per-tab stacks, and the full-screen
/// practice session. A future restriction shield can call `startPractice()` to
/// route a student straight into a session.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var settingsPath: [SettingsRoute] = []
    var practiceLaunch: PracticeLaunch?

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    func startPractice(startingAt index: Int = 0) {
        practiceLaunch = PracticeLaunch(startingAt: index)
    }

    func dismissPractice() {
        practiceLaunch = nil
    }

    /// Jumps to a specific settings screen from anywhere.
    func open(_ route: SettingsRoute) {
        selectedTab = .settings
        settingsPath = [route]
    }
}
