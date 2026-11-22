import Foundation
import Observation

/// Frontend-only question. Original demonstration content; production
/// question delivery and session management belong to the systems agent.
struct PreviewQuestion: Identifiable, Equatable {
    let id: Int
    let exam: String
    let section: String
    let stem: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String

    var label: String { "\(exam) · \(section)" }
}

/// Temporary presentation state for one practice run.
@Observable
final class PreviewPracticeSession {
    enum Phase: Equatable {
        case answering
        case submitted
        case completed
    }

    let questions: [PreviewQuestion]
    let rewardMinutes: Int
    private(set) var index: Int
    private(set) var phase: Phase = .answering
    private(set) var selectedChoice: Int?
    private(set) var correctCount = 0

    init(questions: [PreviewQuestion] = PreviewQuestion.samples, rewardMinutes: Int = 10, startingAt index: Int = 0) {
        self.questions = questions
        self.rewardMinutes = rewardMinutes
        self.index = min(max(index, 0), max(questions.count - 1, 0))
    }

    var current: PreviewQuestion { questions[index] }
    var total: Int { questions.count }
    var isLastQuestion: Bool { index == total - 1 }
    var progressText: String { "Question \(index + 1) of \(total)" }
    var progressFraction: Double { phase == .completed ? 1 : Double(index + 1) / Double(total) }
    var isCorrect: Bool { selectedChoice == current.correctIndex }
    var canSubmit: Bool { phase == .answering && selectedChoice != nil }

    func select(_ choice: Int) {
        guard phase == .answering, current.choices.indices.contains(choice) else { return }
        selectedChoice = choice
    }

    func submit() {
        guard canSubmit else { return }
        if isCorrect { correctCount += 1 }
        phase = .submitted
    }

    /// Moves to the next question, or completes the session after the last one.
    func advance() {
        guard phase == .submitted else { return }
        if isLastQuestion {
            phase = .completed
        } else {
            index += 1
            selectedChoice = nil
            phase = .answering
        }
    }
}

extension PreviewQuestion {
    static let samples: [PreviewQuestion] = [
        .init(id: 1, exam: "SAT", section: "Math",
              stem: "A phone plan costs $20 per month plus $5 for each gigabyte of data. Last month the bill was $55. How many gigabytes were used?",
              choices: ["5", "6", "7", "8"], correctIndex: 2,
              explanation: "Subtract the $20 base: 55 − 20 = 35. Then divide by $5 per gigabyte: 35 ÷ 5 = 7."),
        .init(id: 2, exam: "SAT", section: "Math",
              stem: "What is 15% of 80?",
              choices: ["8", "10", "12", "15"], correctIndex: 2,
              explanation: "15% is 0.15, and 0.15 × 80 = 12."),
        .init(id: 3, exam: "SAT", section: "Math",
              stem: "At what point does the line y = 2x + 3 cross the y-axis?",
              choices: ["(0, 2)", "(0, 3)", "(3, 0)", "(2, 3)"], correctIndex: 1,
              explanation: "The y-axis is where x = 0. Substituting gives y = 3, so the point is (0, 3)."),
        .init(id: 4, exam: "SAT", section: "Math",
              stem: "If 3x + 7 = 22, what is the value of x?",
              choices: ["3", "5", "7", "9"], correctIndex: 1,
              explanation: "Subtract 7 from both sides to get 3x = 15, then divide by 3: x = 5."),
        .init(id: 5, exam: "SAT", section: "Math",
              stem: "If f(x) = x² − 4, what is f(3)?",
              choices: ["2", "5", "9", "13"], correctIndex: 1,
              explanation: "Replace x with 3: 3² − 4 = 9 − 4 = 5."),
        .init(id: 6, exam: "SAT", section: "Math",
              stem: "A rectangle is 8 units long and 5 units wide. What is its perimeter?",
              choices: ["13", "26", "40", "45"], correctIndex: 1,
              explanation: "Perimeter is 2 × (length + width) = 2 × 13 = 26."),
        .init(id: 7, exam: "SAT", section: "Writing",
              stem: "Which choice completes the sentence correctly?\n\nThe debate team ______ practicing every day since September.",
              choices: ["has been", "have being", "are been", "were being"], correctIndex: 0,
              explanation: "“Team” is singular here, and “since September” calls for the present perfect progressive: “has been practicing.”"),
        .init(id: 8, exam: "SAT", section: "Reading",
              stem: "Which word best completes the sentence?\n\nAlthough the first results were ______, the researchers repeated the experiment to be certain.",
              choices: ["promising", "irrelevant", "hostile", "casual"], correctIndex: 0,
              explanation: "“Although” signals contrast. Results that looked good, but weren't yet confirmed, explain why the experiment was repeated."),
        .init(id: 9, exam: "SAT", section: "Writing",
              stem: "Which revision of the underlined sentence is most concise?\n\n“Due to the fact that it was raining, the game was postponed.”",
              choices: ["Because it rained, the game was postponed.",
                        "The game, on account of rain, it was postponed.",
                        "It was raining so the game was postponed because of that.",
                        "Due to rain being the case, the game was postponed."], correctIndex: 0,
              explanation: "“Because it rained” replaces a wordy phrase with the same meaning and keeps the sentence grammatical."),
        .init(id: 10, exam: "SAT", section: "Reading",
              stem: "Urban gardens can lower neighborhood temperatures and give residents fresh produce. Cities that support them often see more community involvement.\n\nWhich choice best states the main idea?",
              choices: ["Urban gardens provide several benefits to cities.",
                        "Fresh produce is cheaper in cities.",
                        "Cities should replace all lawns.",
                        "Community involvement is declining."], correctIndex: 0,
              explanation: "The passage lists cooler temperatures, fresh produce, and community involvement, all as benefits of urban gardens."),
    ]
}
