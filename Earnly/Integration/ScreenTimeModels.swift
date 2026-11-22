import Foundation

// Presentation-facing value types. Each mirrors a concept owned by the systems
// package (`EarnlySystems`) and is produced by a `ScreenTimeServicing` adapter.
// Views never import Apple Screen Time frameworks or systems domain types.
// See docs/frontend-phase2.md for the exact mapping.

enum DataProvenance: String, Equatable {
    case observed, estimated, simulated
}

/// Mirrors `AuthorizationState`.
enum AuthorizationStatus: String, Equatable {
    case notDetermined, approved, denied, revoked, unavailable
}

/// Mirrors `ActivitySelection`: counts and an opaque ID only. Tokens stay inside the adapter.
struct ActivitySelectionSummary: Equatable, Identifiable {
    let id: UUID
    var applications: Int
    var categories: Int
    var webDomains: Int

    var isEmpty: Bool { applications + categories + webDomains == 0 }

    var description: String {
        var parts: [String] = []
        if applications > 0 { parts.append(applications == 1 ? "1 app" : "\(applications) apps") }
        if categories > 0 { parts.append(categories == 1 ? "1 category" : "\(categories) categories") }
        if webDomains > 0 { parts.append(webDomains == 1 ? "1 website" : "\(webDomains) websites") }
        return parts.isEmpty ? "Nothing selected" : parts.joined(separator: ", ")
    }
}

/// Mirrors `ScreenTimePolicy`. Allowance, question count and reward are independent values.
struct PolicySummary: Equatable {
    var allowanceMinutes: Int
    var requiredQuestions: Int
    var rewardMinutes: Int
    var isEnabled: Bool = true

    static let allowanceOptions = [10, 15]
    static let standard = PolicySummary(allowanceMinutes: 10, requiredQuestions: 10, rewardMinutes: 10)
}

enum RestrictionFailureKind: String, Equatable {
    case monitoring, shield, thresholdBeforeRelease
}

/// Mirrors `RestrictionState` without session identifiers (those live in the snapshot).
enum LifecycleStage: Equatable {
    case unconfigured
    case configuring            // monitoring is being installed
    case selectionRequired      // saved selection is no longer valid
    case available              // allowance active, apps not restricted
    case applyingShield
    case restricted
    case practiceInProgress
    case rewardPending          // session complete; credit and/or release not finished
    case authorizationUnavailable
    case failed(RestrictionFailureKind)
}

/// A credit that has been recorded. `releaseFailed` is the systems layer reporting that the
/// shield could not be removed; the credit itself is never repeated.
struct PendingReward: Equatable {
    let sessionID: UUID
    let minutes: Int
    var releaseFailed: Bool
}

struct RewardEntry: Identifiable, Equatable {
    let id: UUID
    let earnedAt: Date
    let minutes: Int
    let correct: Int
    let total: Int
    /// True once the systems layer reports that the threshold for this credit was reached.
    /// A lower bound on use, not a measurement.
    let thresholdReached: Bool
}

struct PracticeOption: Equatable, Identifiable {
    let id: String
    let text: String
}

struct PracticeQuestion: Equatable, Identifiable {
    let id: String
    let label: String
    let stem: String
    let options: [PracticeOption]
    let correctAnswerID: String
    let explanation: String
}

struct PracticeAttempt: Equatable {
    let questionID: String
    let answerID: String
    let isCorrect: Bool
}

/// Mirrors `PracticeSession`. Completion is `isComplete`, never a local count.
struct PracticeSnapshot: Equatable, Identifiable {
    let id: UUID
    let questions: [PracticeQuestion]
    let attempts: [PracticeAttempt]
    let rewardMinutes: Int
    let isComplete: Bool

    var answeredCount: Int { attempts.count }
    var correctCount: Int { attempts.filter(\.isCorrect).count }
    var total: Int { questions.count }
    var nextQuestion: PracticeQuestion? {
        questions.first { q in !attempts.contains { $0.questionID == q.id } }
    }
}

/// Mirrors `DashboardSnapshot` plus the reward and history details the presentation needs.
struct ServiceSnapshot: Equatable {
    var authorization: AuthorizationStatus
    var stage: LifecycleStage
    var policy: PolicySummary
    var selection: ActivitySelectionSummary?
    var cycleID: UUID?
    var activeSession: PracticeSnapshot?
    var pendingReward: PendingReward?
    /// Minutes of the reward credit that has been released in the current cycle.
    var releasedRewardMinutes: Int?
    var earnedMinutes: Int?
    /// Lower bound from a reached threshold. Not remaining time.
    var thresholdEvidenceMinutes: Int?
    /// nil when the platform cannot supply a measurement. Currently always nil in production.
    var remainingMinutes: Int?
    var rewardHistory: [RewardEntry] = []
    var provenance: DataProvenance

    static func fresh(provenance: DataProvenance) -> ServiceSnapshot {
        ServiceSnapshot(
            authorization: .notDetermined, stage: .unconfigured, policy: .standard,
            selection: nil, cycleID: nil, activeSession: nil, pendingReward: nil,
            releasedRewardMinutes: nil, earnedMinutes: 0, thresholdEvidenceMinutes: nil,
            remainingMinutes: nil, provenance: provenance)
    }
}
