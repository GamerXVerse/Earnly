import Foundation
import Testing
@testable import EarnlySystems

struct PolicyAndPracticeTests {
    @Test func policyDefaultsAndIndependentConfiguration() throws {
        let standard = ScreenTimePolicy.standard
        #expect(standard.initialAllowance == .ten)
        #expect(standard.requiredQuestions == 10)
        #expect(standard.rewardedMinutes == 10)
        #expect(standard.isEnabled)

        let other = try ScreenTimePolicy(initialAllowance: .fifteen, requiredQuestions: 2,
                                         rewardedMinutes: 7, isEnabled: false)
        #expect(try JSONDecoder().decode(ScreenTimePolicy.self, from: JSONEncoder().encode(other)) == other)
        #expect(other.initialAllowance.rawValue == 15)
        #expect(other.requiredQuestions == 2)
        #expect(other.rewardedMinutes == 7)
    }

    @Test func badPolicyIsRejectedAtConstructionAndDecode() {
        #expect(throws: PolicyError.invalidQuestionCount) { try ScreenTimePolicy(requiredQuestions: 0) }
        #expect(throws: PolicyError.invalidRewardMinutes) { try ScreenTimePolicy(rewardedMinutes: -1) }
        let invalidAllowance = Data(#"{"initialAllowance":12,"requiredQuestions":10,"rewardedMinutes":10,"isEnabled":true}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTimePolicy.self, from: invalidAllowance)
        }
        let invalidCount = Data(#"{"initialAllowance":15,"requiredQuestions":0,"rewardedMinutes":10,"isEnabled":true}"#.utf8)
        #expect(throws: PolicyError.invalidQuestionCount) {
            try JSONDecoder().decode(ScreenTimePolicy.self, from: invalidCount)
        }
    }

    @Test func catalogFiltersByExamIncludingAPSubject() throws {
        let profile = StudyProfile(exams: [.ap(subjectCode: "statistics")])
        let demo = DemoQuestions()
        #expect(try demo.questions(for: profile, count: 10).map(\.id) == ["ap-stat-01"])
        #expect(try demo.questions(for: StudyProfile(), count: 10).count == 10)
        #expect(try demo.questions(for: StudyProfile(preferredDifficulty: .advanced), count: 1).first?.id == "sat-10")
    }

    @Test func sessionValidatesSubmissionAndConflictingDuplicate() throws {
        let date = Date(timeIntervalSince1970: 500)
        let question = try #require(DemoQuestions().questions(for: StudyProfile(), count: 1).first)
        let wrong = try #require(question.options.first { $0.id != question.correctAnswerID })
        let policy = try ScreenTimePolicy(requiredQuestions: 1)
        var session = try PracticeSession(id: UUID(), startedAt: date, questions: [question], policy: policy)

        #expect(throws: PracticeError.unknownQuestion) {
            try session.submit(questionID: "unknown", answerID: wrong.id, at: date)
        }
        #expect(throws: PracticeError.unknownAnswer) {
            try session.submit(questionID: question.id, answerID: "unknown", at: date)
        }
        #expect(throws: PracticeError.invalidTimestamp) {
            try session.submit(questionID: question.id, answerID: wrong.id, at: date.addingTimeInterval(-1))
        }
        try session.submit(questionID: question.id, answerID: wrong.id, at: date)
        try session.submit(questionID: question.id, answerID: wrong.id, at: date.addingTimeInterval(5))
        #expect(throws: PracticeError.alreadyAnswered) {
            try session.submit(questionID: question.id, answerID: question.correctAnswerID, at: date)
        }
        #expect(session.attempts.count == 1)
        #expect(session.correctAnswers == 0)
        #expect(session.completedAt == date)
        #expect(session.isValid)
    }
}
