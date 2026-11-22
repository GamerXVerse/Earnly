import SwiftUI

/// Typography built on SF Pro through SwiftUI text styles, so everything
/// scales with Dynamic Type.
enum EarnlyFont {
    /// Page titles (~34 pt at default size).
    static let pageTitle = Font.largeTitle.weight(.bold)
    /// Smaller page title used in compact headers (~28 pt).
    static let titleMedium = Font.title.weight(.bold)
    /// Section headings (~20 pt).
    static let sectionHeading = Font.title3.weight(.semibold)
    /// Body (~17 pt).
    static let body = Font.body
    static let bodyEmphasis = Font.body.weight(.semibold)
    /// Question stems: slightly larger reading size.
    static let reading = Font.system(.title3, design: .default).weight(.medium)
    /// Secondary information (~15 pt).
    static let secondary = Font.subheadline
    static let secondaryEmphasis = Font.subheadline.weight(.semibold)
    /// Caption (~13 pt).
    static let caption = Font.footnote
    static let captionEmphasis = Font.footnote.weight(.semibold)
    /// Stat numbers (~28 pt, monospaced digits).
    static let stat = Font.title.weight(.semibold).monospacedDigit()
}

/// Hero numeric display (44–60 pt) that scales with Dynamic Type.
private struct HeroNumber: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1
    let baseSize: CGFloat
    private var size: CGFloat { baseSize * scale }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold, design: .default).monospacedDigit())
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }
}

private struct Overline: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote.weight(.medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(EarnlyColor.inkSecondary)
    }
}

extension View {
    func earnlyHeroNumber(baseSize: CGFloat = 56) -> some View {
        modifier(HeroNumber(baseSize: baseSize))
    }

    /// Small uppercase label above a value.
    func earnlyOverline() -> some View {
        modifier(Overline())
    }
}
