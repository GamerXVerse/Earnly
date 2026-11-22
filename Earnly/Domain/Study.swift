import Foundation

/// AP uses a stable catalog code so subject additions require no schema change.
public enum ExamType: Codable, Hashable, Sendable {
    case sat
    case psat
    case act
    case ap(subjectCode: String)
}

/// An empty set means the learner has yet to choose an exam.
public struct StudyProfile: Codable, Equatable, Sendable {
    public var exams: Set<ExamType>
    public var preferredDifficulty: QuestionDifficulty?

    public init(exams: Set<ExamType> = [], preferredDifficulty: QuestionDifficulty? = nil) {
        self.exams = exams
        self.preferredDifficulty = preferredDifficulty
    }
}

public enum InitialAllowance: Int, Codable, CaseIterable, Sendable {
    case ten = 10
    case fifteen = 15
}

public enum PolicyError: Error, Equatable, Sendable {
    case invalidQuestionCount
    case invalidRewardMinutes
}

/// Independent values. The same validation applies to user input and persisted data.
public struct ScreenTimePolicy: Codable, Equatable, Sendable {
    public static let standard = ScreenTimePolicy()

    public let initialAllowance: InitialAllowance
    public let requiredQuestions: Int
    public let rewardedMinutes: Int
    public let isEnabled: Bool

    private init() {
        initialAllowance = .ten
        requiredQuestions = 10
        rewardedMinutes = 10
        isEnabled = true
    }

    public init(
        initialAllowance: InitialAllowance = .ten,
        requiredQuestions: Int = 10,
        rewardedMinutes: Int = 10,
        isEnabled: Bool = true
    ) throws {
        guard requiredQuestions > 0 else { throw PolicyError.invalidQuestionCount }
        guard rewardedMinutes > 0 else { throw PolicyError.invalidRewardMinutes }
        self.initialAllowance = initialAllowance
        self.requiredQuestions = requiredQuestions
        self.rewardedMinutes = rewardedMinutes
        self.isEnabled = isEnabled
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            initialAllowance: fields.decode(InitialAllowance.self, forKey: .initialAllowance),
            requiredQuestions: fields.decode(Int.self, forKey: .requiredQuestions),
            rewardedMinutes: fields.decode(Int.self, forKey: .rewardedMinutes),
            isEnabled: fields.decode(Bool.self, forKey: .isEnabled)
        )
    }
}

public enum QuestionDifficulty: String, Codable, CaseIterable, Sendable {
    case introductory, intermediate, advanced
}

public struct AnswerOption: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

/// Question identifiers are stable within the catalog. Each question has unique options
/// and its answer key must identify one of those options.
public struct EarnlyQuestion: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let exam: ExamType
    public let topic: String
    public let difficulty: QuestionDifficulty
    public let stem: String
    public let options: [AnswerOption]
    public let correctAnswerID: AnswerOption.ID
    public let explanation: String

    public init(
        id: String, exam: ExamType, topic: String, difficulty: QuestionDifficulty,
        stem: String, options: [AnswerOption], correctAnswerID: AnswerOption.ID, explanation: String
    ) {
        self.id = id
        self.exam = exam
        self.topic = topic
        self.difficulty = difficulty
        self.stem = stem
        self.options = options
        self.correctAnswerID = correctAnswerID
        self.explanation = explanation
    }

    var isValid: Bool {
        !id.isEmpty && !stem.isEmpty && options.count >= 2
            && Set(options.map(\.id)).count == options.count
            && options.contains { $0.id == correctAnswerID }
    }
}
