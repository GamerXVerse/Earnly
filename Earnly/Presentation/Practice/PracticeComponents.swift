import SwiftUI

/// Question text with reading-friendly size and line spacing.
struct QuestionStem: View {
    let text: String

    var body: some View {
        Text(text)
            .font(EarnlyFont.reading)
            .lineSpacing(5)
            .foregroundStyle(EarnlyColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct AnswerList: View {
    let session: PreviewPracticeSession

    var body: some View {
        VStack(spacing: EarnlySpacing.sm) {
            ForEach(Array(session.current.choices.enumerated()), id: \.offset) { index, text in
                AnswerOptionRow(
                    letter: letter(index),
                    text: text,
                    state: state(for: index)
                ) {
                    EarnlyHaptics.selection()
                    session.select(index)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Answer choices")
    }

    private func letter(_ index: Int) -> String {
        String(UnicodeScalar(UInt8(65 + index)))
    }

    private func state(for index: Int) -> AnswerOptionRow.State {
        switch session.phase {
        case .answering:
            return session.selectedChoice == index ? .selected : .idle
        default:
            if index == session.current.correctIndex { return .correct }
            if index == session.selectedChoice { return .incorrect }
            return .dimmed
        }
    }
}

struct AnswerOptionRow: View {
    enum State { case idle, selected, correct, incorrect, dimmed }

    let letter: String
    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EarnlySpacing.md) {
                Text(letter)
                    .font(EarnlyFont.bodyEmphasis)
                    .foregroundStyle(letterColor)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(text)
                    .font(EarnlyFont.body)
                    .foregroundStyle(state == .dimmed ? EarnlyColor.inkSecondary : EarnlyColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: EarnlySpacing.xs)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(symbolColor)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, EarnlySpacing.md)
            .padding(.vertical, EarnlySpacing.sm)
            .frame(maxWidth: .infinity, minHeight: EarnlyGeometry.minTouchTarget + EarnlySpacing.xs, alignment: .leading)
            .background(background)
            .overlay(border)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .correct || state == .incorrect || state == .dimmed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Choice \(letter): \(text)")
        .accessibilityValue(accessibilityState)
        .accessibilityAddTraits(state == .selected ? [.isButton, .isSelected] : .isButton)
        .earnlyAnimation(EarnlyMotion.quick, value: state)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: EarnlyGeometry.radiusControl, style: .continuous)
    }

    private var background: some View {
        shape.fill(fill)
    }

    private var border: some View {
        shape.strokeBorder(stroke, lineWidth: strokeWidth)
    }

    private var fill: Color {
        switch state {
        case .selected: return EarnlyColor.brandTint
        case .correct: return EarnlyColor.successTint
        case .incorrect: return EarnlyColor.errorTint
        case .idle, .dimmed: return EarnlyColor.surface
        }
    }

    private var stroke: Color {
        switch state {
        case .selected: return EarnlyColor.brand
        case .correct: return EarnlyColor.successText
        case .incorrect: return EarnlyColor.error
        case .idle, .dimmed: return EarnlyColor.outline
        }
    }

    private var strokeWidth: CGFloat {
        switch state {
        case .idle, .dimmed: return EarnlyGeometry.hairline
        default: return EarnlyGeometry.selectedBorder
        }
    }

    private var letterColor: Color {
        state == .selected ? EarnlyColor.brandText : EarnlyColor.inkSecondary
    }

    private var symbol: String? {
        switch state {
        case .selected: return "checkmark.circle"
        case .correct: return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        default: return nil
        }
    }

    private var symbolColor: Color {
        switch state {
        case .selected: return EarnlyColor.brandText
        case .correct: return EarnlyColor.successText
        default: return EarnlyColor.error
        }
    }

    private var accessibilityState: String {
        switch state {
        case .idle, .dimmed: return ""
        case .selected: return "Selected"
        case .correct: return "Correct answer"
        case .incorrect: return "Your answer, incorrect"
        }
    }
}

/// Result of a submitted answer, with the explanation. Uses an icon and text
/// as well as color so the result never depends on color alone.
struct AnswerFeedback: View {
    let question: PreviewQuestion
    let selected: Int

    private var isCorrect: Bool { selected == question.correctIndex }

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
            Label {
                Text(isCorrect ? "Correct" : "Not quite")
                    .font(EarnlyFont.bodyEmphasis)
            } icon: {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
            }
            .foregroundStyle(isCorrect ? EarnlyColor.successText : EarnlyColor.error)

            if !isCorrect {
                Text("The correct answer is \(String(UnicodeScalar(UInt8(65 + question.correctIndex)))).")
                    .font(EarnlyFont.secondaryEmphasis)
                    .foregroundStyle(EarnlyColor.ink)
            }
            Text(question.explanation)
                .font(EarnlyFont.secondary)
                .foregroundStyle(EarnlyColor.inkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EarnlySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCorrect ? EarnlyColor.successTint : EarnlyColor.errorTint)
        .overlay(alignment: .leading) {
            Rectangle().fill(isCorrect ? EarnlyColor.successText : EarnlyColor.error).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: EarnlyGeometry.radiusSmall, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
