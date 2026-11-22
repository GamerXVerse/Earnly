import Foundation

/// Demonstration analytics. Clearly separate from real user data.
struct PreviewDailyPractice: Identifiable {
    let id = UUID()
    let day: String
    let questions: Int
}

struct PreviewExamPerformance: Identifiable {
    let id = UUID()
    let name: String
    let questionsCompleted: Int
    let accuracy: Double
}

struct PreviewProgressData {
    var week: [PreviewDailyPractice]
    var performance: [PreviewExamPerformance]
    var minutesEarned: Int

    var totalQuestions: Int { week.map(\.questions).reduce(0, +) }
    var overallAccuracy: Double {
        let total = performance.map(\.questionsCompleted).reduce(0, +)
        guard total > 0 else { return 0 }
        return performance.reduce(0) { $0 + $1.accuracy * Double($1.questionsCompleted) } / Double(total)
    }

    static let demo = PreviewProgressData(
        week: [
            .init(day: "Mon", questions: 10), .init(day: "Tue", questions: 20), .init(day: "Wed", questions: 0),
            .init(day: "Thu", questions: 10), .init(day: "Fri", questions: 30), .init(day: "Sat", questions: 10),
            .init(day: "Sun", questions: 20),
        ],
        performance: [
            .init(name: "SAT Math", questionsCompleted: 70, accuracy: 0.74),
            .init(name: "SAT Reading & Writing", questionsCompleted: 30, accuracy: 0.63),
        ],
        minutesEarned: 100)

    static let empty = PreviewProgressData(week: [], performance: [], minutesEarned: 0)
}
