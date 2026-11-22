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
    case exams, screenTime, activities, rewards, permissions, monitoring
    case accessibility, privacy, about
    #if DEBUG
    case development
    #endif
}

struct PracticeLaunch: Identifiable, Equatable {
    let id = UUID()
}

/// Tab selection, per-tab stacks and the full-screen practice cover.
///
/// Activation routing is idempotent: an unfinished session is presented at most once per
/// session ID, so backgrounding and returning never stacks or re-presents practice.
/// A shield can only open Earnly where the platform allows it; when the student opens
/// Earnly manually the same reconciliation lands them on Today with the practice action.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var settingsPath: [SettingsRoute] = []
    var practiceLaunch: PracticeLaunch?
    private(set) var lastRoutedEpisode: String?
    private(set) var presentationCount = 0

    func select(_ tab: AppTab) { selectedTab = tab }

    func startPractice() {
        guard practiceLaunch == nil else { return }
        practiceLaunch = PracticeLaunch()
        presentationCount += 1
    }

    func dismissPractice() { practiceLaunch = nil }

    func open(_ route: SettingsRoute) {
        selectedTab = .settings
        settingsPath = [route]
    }

    /// Call after each reconciliation (launch and foreground entry).
    func routeOnActivation(_ snapshot: ServiceSnapshot?) {
        guard let snapshot, snapshot.authorization == .approved else { return }
        let episode: String
        switch snapshot.stage {
        case .practiceInProgress:
            episode = "session-\(snapshot.activeSession?.id.uuidString ?? "unknown")"
        case .restricted:
            episode = "restricted-\(snapshot.cycleID?.uuidString ?? "unknown")"
        default:
            return
        }
        guard episode != lastRoutedEpisode else { return }
        lastRoutedEpisode = episode
        selectedTab = .today
        // Resume an unfinished session once. With no session, Today shows the start action.
        if case .practiceInProgress = snapshot.stage { startPractice() }
    }
}
