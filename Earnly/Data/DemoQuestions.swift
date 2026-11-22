import Foundation

/// Original sample questions. An empty profile defaults to SAT for evaluation.
public struct DemoQuestions: QuestionProviding {
    public init() {}

    public func questions(for profile: StudyProfile, count: Int) throws -> [EarnlyQuestion] {
        guard count > 0 else { throw PolicyError.invalidQuestionCount }
        let exams = profile.exams.isEmpty ? [.sat] : profile.exams
        let matching = Self.catalog.filter { exams.contains($0.exam) }
        guard let preference = profile.preferredDifficulty else { return Array(matching.prefix(count)) }
        let preferred = matching.filter { $0.difficulty == preference }
        let others = matching.filter { $0.difficulty != preference }
        return Array((preferred + others).prefix(count))
    }

    private static let catalog: [EarnlyQuestion] = [
        question("sat-01", .sat, "Linear equations", .introductory,
                 "A repair service charges a flat fee of $24 plus $9 per hour. How many hours cost $69?",
                 ["4", "5", "6", "7"], 1, "Subtract the $24 fee, then divide $45 by $9."),
        question("sat-02", .sat, "Rates", .introductory,
                 "A printer produces 42 pages in 3 minutes at a constant rate. How many pages does it produce in 8 minutes?",
                 ["96", "105", "112", "126"], 2, "The rate is 14 pages per minute. Multiply by 8."),
        question("sat-03", .sat, "Percentages", .intermediate,
                 "After a 20% discount, a backpack costs $36. What was the original price?",
                 ["$40", "$43.20", "$48", "$45"], 3, "$36 is 80% of the original price, so divide $36 by 0.8."),
        question("sat-04", .sat, "Functions", .introductory,
                 "If f(x) = 3x² − 2x, what is f(−2)?",
                 ["16", "8", "−8", "−16"], 0, "Squaring −2 gives 4, and subtracting twice −2 adds another 4."),
        question("sat-05", .sat, "Geometry", .introductory,
                 "A rectangular mural has a perimeter of 34 feet and a length of 11 feet. What is its area?",
                 ["55 square feet", "66 square feet", "77 square feet", "88 square feet"], 1,
                 "The length and width sum to 17 feet, so the width is 6 feet."),
        question("sat-06", .sat, "Statistics", .intermediate,
                 "Four measured lengths have a mean of 12 cm. A fifth measurement of 17 cm is added. What is the new mean?",
                 ["12 cm", "12.5 cm", "13 cm", "14 cm"], 2, "The new total is 4 × 12 + 17 = 65 cm. Divide by 5."),
        question("sat-07", .sat, "Systems of equations", .intermediate,
                 "At a fundraiser, 18 tickets sell for a total of $126. Adult tickets cost $9 and student tickets cost $5. How many adult tickets sold?",
                 ["7", "8", "10", "9"], 3, "If all 18 tickets were student tickets, the total would be $90. Each adult ticket adds $4, so $36 represents 9 adult tickets."),
        question("sat-08", .sat, "Transitions", .intermediate,
                 "Choose the best transition. The new lamp uses less electricity than the old model. ___, it costs more to purchase.",
                 ["However", "For example", "Therefore", "Similarly"], 0, "The second sentence contrasts operating efficiency with purchase cost."),
        question("sat-09", .sat, "Sentence boundaries", .intermediate,
                 "Choose the punctuation that completes the sentence. The tide was rising ___ the researchers moved their equipment uphill.",
                 [",", ";", ":", "— and because"], 1, "A semicolon joins these related independent clauses."),
        question("sat-10", .sat, "Quadratic equations", .advanced,
                 "The equation x² − 7x + k = 0 has x = 3 as a solution. What is k?",
                 ["9", "10", "12", "21"], 2, "Substitute 3 to get 9 − 21 + k = 0, so k = 12."),
        question("sat-11", .sat, "Evidence", .intermediate,
                 "A botanist claims a seed sprouts faster in warmer soil. Which result most directly supports the claim?",
                 ["Warm soil held more water.", "Seeds in warm soil sprouted two days earlier under otherwise identical conditions.", "Larger seeds weighed more.", "The greenhouse had a warmer roof."], 1,
                 "Comparing sprouting time with other conditions controlled directly tests the effect of soil temperature."),
        question("psat-01", .psat, "Proportions", .introductory,
                 "A map uses 2 centimeters to represent 5 kilometers. What distance does 6 centimeters represent?",
                 ["10 km", "12 km", "15 km", "30 km"], 2, "Six centimeters is three times the given scale segment."),
        question("psat-02", .psat, "Word choice", .introductory,
                 "In 'The technician calibrated the scale before the trial,' what does calibrated most nearly mean?",
                 ["Adjusted for accuracy", "Moved to storage", "Weighed", "Replaced"], 0, "Calibration adjusts an instrument to measure accurately."),
        question("act-01", .act, "Probability", .intermediate,
                 "A box holds 3 red, 4 blue, and 5 green tiles. What is the probability of drawing a tile that is not blue?",
                 ["1/4", "1/3", "1/2", "2/3"], 3, "Eight of the twelve tiles are red or green."),
        question("act-02", .act, "Experimental design", .intermediate,
                 "Three identical plants receive different amounts of light and the same amount of water. Which variable did the experimenter deliberately change?",
                 ["Water", "Light", "Plant species", "Soil type"], 1, "The amount of light is the independent variable."),
        question("ap-calc-ab-01", .ap(subjectCode: "calculus-ab"), "Differentiation", .intermediate,
                 "What is the slope of the tangent to f(x) = x³ − 2x at x = 2?",
                 ["2", "6", "10", "12"], 2, "The derivative is 3x² − 2, which equals 10 at x = 2."),
        question("ap-stat-01", .ap(subjectCode: "statistics"), "Sampling", .intermediate,
                 "A school randomly selects classes and surveys every student in those classes. What sampling method is used?",
                 ["Stratified", "Cluster", "Systematic", "Convenience"], 1, "The survey samples entire groups after randomly choosing those groups.")
    ]

    private static func question(
        _ id: String, _ exam: ExamType, _ topic: String, _ difficulty: QuestionDifficulty,
        _ stem: String, _ answers: [String], _ correct: Int, _ explanation: String
    ) -> EarnlyQuestion {
        EarnlyQuestion(id: id, exam: exam, topic: topic, difficulty: difficulty, stem: stem,
                       options: answers.enumerated().map { .init(id: String($0.offset), text: $0.element) },
                       correctAnswerID: String(correct), explanation: explanation)
    }
}
