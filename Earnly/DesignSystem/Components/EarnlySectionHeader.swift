import SwiftUI

struct EarnlySectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(EarnlyFont.sectionHeading)
                .foregroundStyle(EarnlyColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: EarnlySpacing.xs)
            accessory()
        }
    }
}

extension EarnlySectionHeader where Accessory == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// Full-width 1 pt separator.
struct EarnlyDivider: View {
    var body: some View {
        Rectangle()
            .fill(EarnlyColor.separator)
            .frame(height: EarnlyGeometry.hairline)
            .accessibilityHidden(true)
    }
}

/// Marks content that is sample data, not the user's real information.
struct EarnlyPreviewTag: View {
    var text: String = "Preview data"

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(EarnlyColor.inkSecondary)
            .padding(.horizontal, EarnlySpacing.xs)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(EarnlyColor.outline, lineWidth: EarnlyGeometry.hairline)
            )
            .accessibilityLabel(text)
    }
}

/// Flat inline message with a leading rule. Always pairs color with an icon and text.
struct EarnlyStatusMessage: View {
    enum Kind { case info, success, warning, development }

    let kind: Kind
    var title: String? = nil
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: EarnlySpacing.sm) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                if let title {
                    Text(title).font(EarnlyFont.secondaryEmphasis).foregroundStyle(EarnlyColor.ink)
                }
                Text(text).font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(EarnlySpacing.md)
        .background(tint)
        .overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: EarnlyGeometry.radiusSmall, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch kind {
        case .info: return "info.circle"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle"
        case .development: return "wrench.adjustable"
        }
    }

    private var accent: Color {
        switch kind {
        case .info, .development: return EarnlyColor.brandText
        case .success: return EarnlyColor.successText
        case .warning: return EarnlyColor.error
        }
    }

    private var tint: Color {
        switch kind {
        case .info, .development: return EarnlyColor.brandTint
        case .success: return EarnlyColor.successTint
        case .warning: return EarnlyColor.errorTint
        }
    }
}

#Preview("Section + status") {
    VStack(alignment: .leading, spacing: 16) {
        EarnlySectionHeader("Your study activity")
        EarnlyDivider()
        EarnlyPreviewTag()
        EarnlyStatusMessage(kind: .development, title: "Development mode", text: "No Screen Time access was granted.")
        EarnlyStatusMessage(kind: .success, text: "10 minutes earned.")
        EarnlyStatusMessage(kind: .warning, text: "Screen Time access is off.")
    }
    .padding(24)
    .background(EarnlyColor.canvas)
}
