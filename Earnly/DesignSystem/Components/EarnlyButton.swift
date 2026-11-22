import SwiftUI

struct EarnlyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, text }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EarnlyFont.bodyEmphasis)
            .foregroundStyle(foreground)
            .padding(.horizontal, EarnlySpacing.lg)
            .frame(maxWidth: kind == .text ? nil : .infinity, minHeight: kind == .text ? EarnlyGeometry.minTouchTarget : EarnlyGeometry.buttonHeight)
            .background(background(pressed: configuration.isPressed))
            .overlay(border)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : EarnlyMotion.quick, value: configuration.isPressed)
    }

    private var foreground: Color {
        guard isEnabled else { return EarnlyColor.disabledText }
        switch kind {
        case .primary: return EarnlyColor.onBrand
        case .secondary, .text: return EarnlyColor.brandText
        }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch kind {
        case .primary:
            RoundedRectangle(cornerRadius: EarnlyGeometry.radiusControl, style: .continuous)
                .fill(isEnabled ? EarnlyColor.brand : EarnlyColor.disabledFill)
        case .secondary:
            RoundedRectangle(cornerRadius: EarnlyGeometry.radiusControl, style: .continuous)
                .fill(EarnlyColor.surface)
        case .text:
            Color.clear
        }
    }

    @ViewBuilder
    private var border: some View {
        if kind == .secondary {
            RoundedRectangle(cornerRadius: EarnlyGeometry.radiusControl, style: .continuous)
                .strokeBorder(isEnabled ? EarnlyColor.outline : EarnlyColor.separator, lineWidth: EarnlyGeometry.hairline)
        }
    }
}

extension ButtonStyle where Self == EarnlyButtonStyle {
    static var earnlyPrimary: EarnlyButtonStyle { .init(kind: .primary) }
    static var earnlySecondary: EarnlyButtonStyle { .init(kind: .secondary) }
    static var earnlyText: EarnlyButtonStyle { .init(kind: .text) }
}

/// Convenience button. `trailingSymbol` is pushed to the trailing edge.
struct EarnlyButton: View {
    let title: String
    var trailingSymbol: String? = nil
    var kind: EarnlyButtonStyle.Kind = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                if let trailingSymbol {
                    Spacer(minLength: EarnlySpacing.xs)
                    Image(systemName: trailingSymbol).font(.body.weight(.semibold)).accessibilityHidden(true)
                }
            }
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(EarnlyButtonStyle(kind: kind))
    }
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        EarnlyButton(title: "Earn more time", trailingSymbol: "arrow.right") {}
        EarnlyButton(title: "Not now", kind: .secondary) {}
        EarnlyButton(title: "Skip", kind: .text) {}
        EarnlyButton(title: "Disabled") {}.disabled(true)
    }
    .padding(24)
    .background(EarnlyColor.canvas)
}
