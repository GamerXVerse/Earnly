import SwiftUI

enum EarnlyGeometry {
    static let radiusSmall: CGFloat = 8
    static let radiusControl: CGFloat = 10
    static let radiusLarge: CGFloat = 12

    static let minTouchTarget: CGFloat = 44
    static let buttonHeight: CGFloat = 52

    static let hairline: CGFloat = 1
    static let selectedBorder: CGFloat = 2
    static let progressHeight: CGFloat = 6
}

extension View {
    /// Flat rectangular surface with an outline. Selection is communicated by
    /// border weight and tint, never by color alone (rows also show a glyph).
    func earnlyOutlined(selected: Bool = false, radius: CGFloat = EarnlyGeometry.radiusControl) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(selected ? EarnlyColor.brandTint : EarnlyColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        selected ? EarnlyColor.brand : EarnlyColor.outline,
                        lineWidth: selected ? EarnlyGeometry.selectedBorder : EarnlyGeometry.hairline
                    )
            )
    }
}
