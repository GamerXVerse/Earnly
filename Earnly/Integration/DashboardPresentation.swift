import Foundation

/// Everything the Today screen needs, derived only from authoritative service state.
/// Pure and deterministic so it can be unit tested. Views never infer restriction,
/// reward or completion on their own.
struct DashboardPresentation: Equatable {
    enum State: Equatable {
        case loading
        case authorizationRequired, authorizationRecovery
        case selectionRequired
        case monitoringPending, monitoringFailed
        case allowanceActive, rewardEarned
        case applyingRestriction, restrictionFailed
        case restricted
        case practiceInProgress
        case recordingReward, restoringAccess, releaseFailed
    }

    enum Tone: Equatable { case neutral, success, warning }

    enum Action: Equatable {
        case allowAccess, reviewAccess, chooseApps
        case startPractice, resumePractice
        case retryOperation, retryRelease
    }

    struct Hero: Equatable {
        var overline: String
        var value: String
        var caption: String
        /// True only when the value is a platform measurement.
        var isMeasured: Bool
    }

    struct Fact: Equatable { var value: String; var label: String }

    var state: State
    var title: String
    var detail: String
    var tone: Tone
    var hero: Hero?
    var primary: (action: Action, title: String)?
    var progressFraction: Double?
    var facts: [Fact] = []

    static func == (l: DashboardPresentation, r: DashboardPresentation) -> Bool {
        l.state == r.state && l.title == r.title && l.detail == r.detail && l.tone == r.tone
            && l.hero == r.hero && l.primary?.action == r.primary?.action
            && l.primary?.title == r.primary?.title && l.progressFraction == r.progressFraction && l.facts == r.facts
    }

    static func make(from snapshot: ServiceSnapshot?) -> DashboardPresentation {
        guard let s = snapshot else {
            return .init(state: .loading, title: "Loading", detail: "", tone: .neutral)
        }
        let policy = s.policy

        switch s.authorization {
        case .notDetermined:
            return .init(
                state: .authorizationRequired, title: "Allow Screen Time access",
                detail: "Earnly needs Apple's Screen Time permission before it can manage the apps you choose.",
                tone: .warning, primary: (.allowAccess, "Allow Screen Time access"))
        case .denied, .revoked, .unavailable:
            let detail: String
            switch s.authorization {
            case .denied: detail = "Access was declined, so Earnly isn't managing any apps. You can allow it in iOS Settings."
            case .revoked: detail = "Access was turned off, so Earnly stopped managing your apps. Allow it again in iOS Settings to continue."
            default: detail = "Screen Time isn't available on this device right now, so Earnly isn't managing any apps."
            }
            return .init(
                state: .authorizationRecovery, title: "Screen Time access is off", detail: detail,
                tone: .warning, primary: (.reviewAccess, "Review access"))
        case .approved: break
        }

        if s.stage == .selectionRequired || s.stage == .unconfigured || s.selection == nil {
            return .init(
                state: .selectionRequired, title: "Choose the apps to manage",
                detail: s.stage == .selectionRequired
                    ? "Your earlier selection is no longer valid. Choose again to resume monitoring."
                    : "Earnly isn't monitoring anything until you pick apps, categories or websites.",
                tone: .warning, primary: (.chooseApps, "Choose apps"))
        }

        if let reward = s.pendingReward {
            let hero = Hero(overline: "Time earned", value: "+\(reward.minutes) min",
                            caption: reward.releaseFailed ? "Access hasn't been restored yet." : "Restoring access.",
                            isMeasured: false)
            if reward.releaseFailed {
                return .init(
                    state: .releaseFailed, title: "Time earned. Access wasn't restored.",
                    detail: "Your reward is saved. You don't need to answer the questions again.",
                    tone: .warning, hero: hero, primary: (.retryRelease, "Try again"))
            }
            return .init(
                state: .restoringAccess, title: "Time earned. Restoring access.",
                detail: "Your selected apps stay restricted until Earnly confirms access is back.",
                tone: .neutral, hero: hero)
        }
        if s.stage == .rewardPending {
            return .init(
                state: .recordingReward, title: "Session complete",
                detail: "Recording your earned time.", tone: .neutral)
        }

        switch s.stage {
        case .failed(.shield):
            return .init(
                state: .restrictionFailed, title: "Earnly couldn't update your restrictions",
                detail: "Your apps may not match your current allowance. Try again.",
                tone: .warning, primary: (.retryOperation, "Try again"))
        case .failed:
            return .init(
                state: .monitoringFailed, title: "Monitoring isn't running",
                detail: "Earnly couldn't start monitoring your selected apps, so your allowance isn't being tracked.",
                tone: .warning, primary: (.retryOperation, "Try again"))
        case .configuring:
            return .init(
                state: .monitoringPending, title: "Setting up monitoring",
                detail: "Your \(policy.allowanceMinutes)-minute allowance starts once Earnly confirms monitoring is on.",
                tone: .neutral)
        case .applyingShield:
            return .init(
                state: .applyingRestriction, title: "Applying restriction",
                detail: "Your selected apps will be restricted once Apple confirms the change.",
                tone: .neutral)
        case .practiceInProgress:
            let session = s.activeSession
            let answered = session?.answeredCount ?? 0
            let total = session?.total ?? policy.requiredQuestions
            return .init(
                state: .practiceInProgress, title: "Practice session underway",
                detail: "Finish the set to earn \(policy.rewardMinutes) minutes.", tone: .neutral,
                hero: Hero(overline: "In progress", value: "\(answered) of \(total)",
                           caption: "questions answered", isMeasured: false),
                primary: (.resumePractice, "Resume practice"),
                progressFraction: total > 0 ? Double(answered) / Double(total) : 0)
        case .restricted:
            return .init(
                state: .restricted, title: "Time to earn it.",
                detail: "You've used your entertainment allowance. Complete a short practice session to earn more time.",
                tone: .neutral,
                primary: (.startPractice, "Start practice"),
                facts: [.init(value: "\(policy.requiredQuestions)", label: "Practice questions"),
                        .init(value: "\(policy.rewardMinutes)m", label: "Screen time reward")])
        case .available:
            if let minutes = s.releasedRewardMinutes {
                return .init(
                    state: .rewardEarned, title: "\(minutes) minutes earned",
                    detail: "Your selected apps are available again.", tone: .success,
                    hero: Hero(overline: "Time earned", value: "+\(minutes) min",
                               caption: "Access restored.", isMeasured: false))
            }
            if let remaining = s.remainingMinutes {
                return .init(
                    state: .allowanceActive, title: "Screen-time allowance active",
                    detail: "Selected apps are available until the allowance runs out.", tone: .neutral,
                    hero: Hero(overline: "Remaining", value: "\(remaining) min",
                               caption: "of your \(policy.allowanceMinutes)-minute allowance", isMeasured: true))
            }
            return .init(
                state: .allowanceActive, title: "\(policy.allowanceMinutes)-minute allowance active",
                detail: "Selected apps are available. Earnly will restrict them once the allowance is used.",
                tone: .neutral,
                hero: Hero(overline: "Allowance", value: "\(policy.allowanceMinutes) min",
                           caption: "Configured allowance. Remaining time isn't measured.", isMeasured: false))
        default:
            return .init(state: .loading, title: "Loading", detail: "", tone: .neutral)
        }
    }
}
