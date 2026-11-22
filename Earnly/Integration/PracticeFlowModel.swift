import Foundation
import Observation

/// Drives one practice presentation. Question identity, evaluation, saved attempts and
/// completion all come from the service; this type only tracks the selected choice and
/// the in-flight submission.
@MainActor
@Observable
final class PracticeFlowModel {
    enum Phase: Equatable { case loading, failed(ServiceFailure), answering, submitted, completed }

    @ObservationIgnored private let app: AppModel
    private(set) var phase: Phase = .loading
    private(set) var session: PracticeSnapshot?
    private(set) var selectedAnswerID: String?
    private(set) var isSubmitting = false
    private(set) var feedbackQuestion: PracticeQuestion?
    private(set) var lastAttempt: PracticeAttempt?

    init(app: AppModel) { self.app = app }

    var current: PracticeQuestion? { feedbackQuestion ?? session?.nextQuestion }
    var total: Int { session?.total ?? 0 }
    /// 1-based position of the question on screen.
    var position: Int {
        guard let session else { return 0 }
        if let feedbackQuestion, let index = session.questions.firstIndex(of: feedbackQuestion) { return index + 1 }
        return min(session.answeredCount + 1, session.total)
    }
    var progressText: String { "Question \(position) of \(total)" }
    var progressFraction: Double {
        guard let session, session.total > 0 else { return 0 }
        return phase == .completed ? 1 : Double(session.answeredCount) / Double(session.total)
    }
    var isLastQuestion: Bool { session.map { $0.answeredCount >= $0.total } ?? false }
    var canSubmit: Bool { phase == .answering && selectedAnswerID != nil && !isSubmitting }

    /// Starts the session, or resumes the saved one (the service returns the active session).
    func load() async {
        guard session == nil else { return }
        do {
            let started = try await app.service.startPractice()
            session = started
            await app.refreshSnapshot()
            phase = started.isComplete ? .completed : .answering
        } catch let failure as ServiceFailure {
            phase = .failed(failure)
        } catch {
            phase = .failed(.unexpected(error.localizedDescription))
        }
    }

    func select(_ answerID: String) {
        guard phase == .answering, !isSubmitting else { return }
        selectedAnswerID = answerID
    }

    func submit() async {
        guard canSubmit, let session, let question = session.nextQuestion, let answer = selectedAnswerID else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let updated = try await app.service.submitAnswer(sessionID: session.id, questionID: question.id, answerID: answer)
            self.session = updated
            lastAttempt = updated.attempts.first { $0.questionID == question.id }
            feedbackQuestion = question
            phase = .submitted
            await app.refreshSnapshot()
        } catch let failure as ServiceFailure {
            phase = .failed(failure)
        } catch {
            phase = .failed(.unexpected(error.localizedDescription))
        }
    }

    /// Next question, or the completion state when the service says the session is complete.
    func advance() async {
        guard phase == .submitted, let session else { return }
        feedbackQuestion = nil
        selectedAnswerID = nil
        lastAttempt = nil
        if session.isComplete {
            phase = .completed
            await app.completeReward(sessionID: session.id)
        } else {
            phase = .answering
        }
    }

    /// Re-entering a session that was already complete (for example after relaunch).
    func finishIfAlreadyComplete() async {
        if phase == .completed, let session { await app.completeReward(sessionID: session.id) }
    }

    func retry() async {
        session = nil
        phase = .loading
        await load()
    }
}
