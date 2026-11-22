import Foundation

/// Deterministic demonstration states for the Today dashboard.
/// In production these are derived from the systems layer; here they are
/// selected from Settings → Development or from SwiftUI previews.
enum PreviewDashboardState: String, CaseIterable, Identifiable {
    case firstLaunchIncomplete
    case available
    case exhausted
    case practiceRequired
    case practiceInProgress
    case earned
    case authorizationUnavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstLaunchIncomplete: return "First launch, setup incomplete"
        case .available: return "Screen time available"
        case .exhausted: return "Allowance used up"
        case .practiceRequired: return "Practice required"
        case .practiceInProgress: return "Practice in progress"
        case .earned: return "Additional time earned"
        case .authorizationUnavailable: return "Authorization unavailable"
        }
    }
}

/// What the Today screen needs to render one state.
struct PreviewRestrictionState: Equatable {
    enum Tone { case neutral, success, warning }
    enum PrimaryAction: Equatable {
        case finishSetup
        case startPractice
        case resumePractice
        case reviewPermission
    }

    /// nil means remaining time is unknown and shown as "--:--".
    var remainingSeconds: Int?
    var allowanceSeconds: Int
    var statusTitle: String
    var statusDetail: String
    var tone: Tone
    var primaryAction: PrimaryAction
    var primaryTitle: String
    var secondaryPracticeTitle: String?
    var questionsToday: Int?
    var minutesEarnedToday: Int?
    var sessionProgress: String?

    var remainingText: String {
        guard let remainingSeconds else { return "--:--" }
        return String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var remainingFraction: Double {
        guard let remainingSeconds, allowanceSeconds > 0 else { return 0 }
        return min(Double(remainingSeconds) / Double(allowanceSeconds), 1)
    }

    var accessibilityRemaining: String {
        guard let remainingSeconds else { return "Remaining time unavailable" }
        return "\(remainingSeconds / 60) minutes \(remainingSeconds % 60) seconds remaining"
    }

    static func make(for state: PreviewDashboardState, profile: PreviewStudyProfile) -> PreviewRestrictionState {
        let allowance = profile.allowanceMinutes * 60
        let reward = "\(profile.rewardQuestions) questions earn \(profile.rewardMinutes) minutes."
        switch state {
        case .firstLaunchIncomplete:
            return .init(
                remainingSeconds: nil, allowanceSeconds: allowance,
                statusTitle: "Setup isn't finished",
                statusDetail: "Choose your exams, allowance, and apps to start earning time.",
                tone: .warning, primaryAction: .finishSetup, primaryTitle: "Finish setup",
                secondaryPracticeTitle: nil, questionsToday: nil, minutesEarnedToday: nil, sessionProgress: nil)
        case .available:
            return .init(
                remainingSeconds: 8 * 60 + 42, allowanceSeconds: allowance,
                statusTitle: "Screen time available",
                statusDetail: "Practice any time to bank extra minutes.",
                tone: .neutral, primaryAction: .startPractice, primaryTitle: "Earn more time",
                secondaryPracticeTitle: nil, questionsToday: 20, minutesEarnedToday: 20, sessionProgress: nil)
        case .exhausted:
            return .init(
                remainingSeconds: 0, allowanceSeconds: allowance,
                statusTitle: "Allowance used up",
                statusDetail: "Selected apps are restricted. \(reward)",
                tone: .warning, primaryAction: .startPractice, primaryTitle: "Practice to unlock",
                secondaryPracticeTitle: nil, questionsToday: 20, minutesEarnedToday: 20, sessionProgress: nil)
        case .practiceRequired:
            return .init(
                remainingSeconds: 0, allowanceSeconds: allowance,
                statusTitle: "Practice required",
                statusDetail: "You were sent here from a restricted app. \(reward)",
                tone: .warning, primaryAction: .startPractice, primaryTitle: "Start \(profile.rewardQuestions) questions",
                secondaryPracticeTitle: nil, questionsToday: 20, minutesEarnedToday: 20, sessionProgress: nil)
        case .practiceInProgress:
            return .init(
                remainingSeconds: 0, allowanceSeconds: allowance,
                statusTitle: "Practice session underway",
                statusDetail: "Finish the set to earn \(profile.rewardMinutes) minutes.",
                tone: .neutral, primaryAction: .resumePractice, primaryTitle: "Resume practice",
                secondaryPracticeTitle: nil, questionsToday: 23, minutesEarnedToday: 20, sessionProgress: "Question 4 of \(profile.rewardQuestions)")
        case .earned:
            return .init(
                remainingSeconds: profile.rewardMinutes * 60, allowanceSeconds: max(allowance, profile.rewardMinutes * 60),
                statusTitle: "\(profile.rewardMinutes) minutes earned",
                statusDetail: "Selected apps are available again.",
                tone: .success, primaryAction: .startPractice, primaryTitle: "Practice more",
                secondaryPracticeTitle: nil, questionsToday: 30, minutesEarnedToday: 30, sessionProgress: nil)
        case .authorizationUnavailable:
            return .init(
                remainingSeconds: nil, allowanceSeconds: allowance,
                statusTitle: "Screen Time access is off",
                statusDetail: "Earnly can't manage your apps without it. Practice still works.",
                tone: .warning, primaryAction: .reviewPermission, primaryTitle: "Review permission",
                secondaryPracticeTitle: "Practice anyway", questionsToday: 20, minutesEarnedToday: nil, sessionProgress: nil)
        }
    }
}
