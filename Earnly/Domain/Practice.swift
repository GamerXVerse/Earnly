import Foundation

public enum PracticeError: Error, Equatable, Sendable {
    case insufficientQuestions(required: Int, available: Int)
    case invalidQuestionSet
    case unknownSession
    case unknownQuestion
    case unknownAnswer
    case alreadyAnswered
    case sessionComplete
    case incompleteSession
    case invalidTimestamp
}

/// A question can have one immutable submitted answer in a session.
public struct QuestionAttempt: Codable, Equatable, Identifiable, Sendable {
    public var id: EarnlyQuestion.ID { questionID }
    public let questionID: EarnlyQuestion.ID
    public let answerID: AnswerOption.ID
    public let isCorrect: Bool
    public let submittedAt: Date
}

/// Captures the exact question set and reward terms in effect when practice begins.
/// Completion requires a valid answer for each question, regardless of accuracy.
public struct PracticeSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let questions: [EarnlyQuestion]
    public let rewardMinutes: Int
    public private(set) var attempts: [QuestionAttempt] = []
    public private(set) var completedAt: Date?

    public var requiredQuestions: Int { questions.count }
    public var answeredQuestions: Int { attempts.count }
    public var correctAnswers: Int { attempts.filter(\.isCorrect).count }
    public var isComplete: Bool { completedAt != nil }

    init(id: UUID, startedAt: Date, questions: [EarnlyQuestion], policy: ScreenTimePolicy) throws {
        guard questions.count == policy.requiredQuestions,
              Set(questions.map(\.id)).count == questions.count,
              questions.allSatisfy(\.isValid) else { throw PracticeError.invalidQuestionSet }
        self.id = id
        self.startedAt = startedAt
        self.questions = questions
        rewardMinutes = policy.rewardedMinutes
    }

    mutating func submit(questionID: EarnlyQuestion.ID, answerID: AnswerOption.ID, at date: Date) throws {
        if let previous = attempts.first(where: { $0.questionID == questionID }) {
            guard previous.answerID == answerID else { throw PracticeError.alreadyAnswered }
            return
        }
        guard !isComplete else { throw PracticeError.sessionComplete }
        guard let question = questions.first(where: { $0.id == questionID }) else {
            throw PracticeError.unknownQuestion
        }
        guard question.options.contains(where: { $0.id == answerID }) else { throw PracticeError.unknownAnswer }
        guard date >= (attempts.last?.submittedAt ?? startedAt) else { throw PracticeError.invalidTimestamp }
        attempts.append(.init(questionID: questionID, answerID: answerID,
                              isCorrect: answerID == question.correctAnswerID, submittedAt: date))
        if attempts.count == questions.count { completedAt = date }
    }

    var isValid: Bool {
        guard rewardMinutes > 0, !questions.isEmpty, questions.allSatisfy(\.isValid),
              Set(questions.map(\.id)).count == questions.count,
              Set(attempts.map(\.questionID)).count == attempts.count else { return false }
        // Replay submissions so decoding obeys the same invariants as live input.
        var replay = self
        replay.attempts = []
        replay.completedAt = nil
        do {
            for attempt in attempts {
                try replay.submit(questionID: attempt.questionID, answerID: attempt.answerID, at: attempt.submittedAt)
            }
        } catch {
            return false
        }
        return replay == self
    }
}
