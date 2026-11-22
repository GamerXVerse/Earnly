import SwiftUI

/// Accessible selectable row used for exams and allowance options.
/// Selected state shows a heavier border, tint, and a checkmark glyph.
struct EarnlySelectionRow: View {
    enum Indicator { case checkbox, radio }

    let title: String
    var subtitle: String? = nil
    var detail: String? = nil
    let isSelected: Bool
    var indicator: Indicator = .checkbox
    let action: () -> Void

    var body: some View {
        Button {
            EarnlyHaptics.selection()
            action()
        } label: {
            HStack(spacing: EarnlySpacing.md) {
                VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                    Text(title).font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
                    if let subtitle {
                        Text(subtitle).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                    }
                }
                Spacer(minLength: EarnlySpacing.xs)
                if let detail {
                    Text(detail).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                }
                SelectionIndicator(isSelected: isSelected, kind: indicator)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, EarnlySpacing.md)
            .padding(.vertical, EarnlySpacing.sm)
            .frame(maxWidth: .infinity, minHeight: EarnlyGeometry.minTouchTarget + EarnlySpacing.xs, alignment: .leading)
            .earnlyOutlined(selected: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .earnlyAnimation(EarnlyMotion.quick, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct SelectionIndicator: View {
    let isSelected: Bool
    var kind: EarnlySelectionRow.Indicator = .checkbox

    var body: some View {
        Group {
            if kind == .radio {
                indicator(Circle())
            } else {
                indicator(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }

    private func indicator<S: InsettableShape>(_ shape: S) -> some View {
        ZStack {
            shape.strokeBorder(isSelected ? EarnlyColor.brand : EarnlyColor.outline, lineWidth: 1.5)
            if isSelected {
                shape.fill(EarnlyColor.brand)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(EarnlyColor.onBrand)
            }
        }
    }
}

#Preview("Selection rows") {
    VStack(spacing: 12) {
        EarnlySelectionRow(title: "SAT", subtitle: "Math, Reading & Writing", isSelected: true) {}
        EarnlySelectionRow(title: "ACT", subtitle: "English, Math, Reading, Science", isSelected: false) {}
        EarnlySelectionRow(title: "10 minutes", isSelected: true, indicator: .radio) {}
    }
    .padding(24)
    .background(EarnlyColor.canvas)
}
