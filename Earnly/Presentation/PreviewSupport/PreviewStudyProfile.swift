import Foundation
import Observation

/// Frontend-only exam selection. NOT persisted and not part of the screen-time policy.
/// Maps to the systems `StudyProfile` / `ExamType` at integration (see docs/frontend-phase2.md).
enum PreviewExam: String, CaseIterable, Identifiable, Hashable {
    case sat, psat, act, ap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sat: return "SAT"
        case .psat: return "PSAT"
        case .act: return "ACT"
        case .ap: return "AP"
        }
    }

    var subtitle: String {
        switch self {
        case .sat: return "Math, Reading & Writing"
        case .psat: return "Math, Reading & Writing"
        case .act: return "English, Math, Reading, Science"
        case .ap: return "Choose individual exams"
        }
    }
}

enum PreviewAPSubject: String, CaseIterable, Identifiable, Hashable {
    case calculusAB = "Calculus AB"
    case biology = "Biology"
    case chemistry = "Chemistry"
    case englishLanguage = "English Language"
    case psychology = "Psychology"
    case usHistory = "U.S. History"

    var id: String { rawValue }
}

@Observable
final class PreviewStudyProfile {
    var selectedExams: Set<PreviewExam>
    var selectedAPSubjects: Set<PreviewAPSubject>

    init(
        selectedExams: Set<PreviewExam> = [],
        selectedAPSubjects: Set<PreviewAPSubject> = []
    ) {
        self.selectedExams = selectedExams
        self.selectedAPSubjects = selectedAPSubjects
    }

    static var sample: PreviewStudyProfile {
        PreviewStudyProfile(selectedExams: [.sat])
    }

    func toggle(_ exam: PreviewExam) {
        if selectedExams.contains(exam) {
            selectedExams.remove(exam)
            if exam == .ap { selectedAPSubjects.removeAll() }
        } else {
            selectedExams.insert(exam)
        }
    }

    func toggle(_ subject: PreviewAPSubject) {
        if selectedAPSubjects.contains(subject) {
            selectedAPSubjects.remove(subject)
        } else {
            selectedAPSubjects.insert(subject)
            selectedExams.insert(.ap)
        }
    }

    /// Ordered selections for display.
    var orderedExams: [PreviewExam] {
        PreviewExam.allCases.filter(selectedExams.contains)
    }

    var primaryExamTitle: String {
        guard let first = orderedExams.first else { return "No exam selected" }
        return "\(first.title) preparation"
    }

    var primaryExamSubtitle: String {
        guard let first = orderedExams.first else { return "Choose an exam to practice" }
        let extra = orderedExams.count - 1
        if first == .ap, !selectedAPSubjects.isEmpty {
            return selectedAPSubjects.map(\.rawValue).sorted().joined(separator: ", ")
        }
        return extra > 0 ? "\(first.subtitle) · +\(extra) more" : first.subtitle
    }

    var examSummary: String {
        let names = orderedExams.map { exam -> String in
            if exam == .ap, !selectedAPSubjects.isEmpty { return "AP (\(selectedAPSubjects.count))" }
            return exam.title
        }
        return names.isEmpty ? "None selected" : names.joined(separator: ", ")
    }
}
