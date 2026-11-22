import SwiftUI

/// Original vector geometry for the Earnly mark: an unlocked padlock whose
/// body carries an integrated checkmark. All shapes are defined in a unit
/// square and scale without pixelation.
struct EarnlyShackleShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        // Left leg stays seated in the body; right leg is lifted clear (unlocked).
        path.move(to: p(0.30, 0.48))
        path.addLine(to: p(0.30, 0.34))
        path.addCurve(to: p(0.50, 0.14), control1: p(0.30, 0.23), control2: p(0.39, 0.14))
        path.addCurve(to: p(0.70, 0.34), control1: p(0.61, 0.14), control2: p(0.70, 0.23))
        path.addLine(to: p(0.70, 0.36))
        return path
    }
}

struct EarnlyLockBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let body = CGRect(
            x: rect.minX + 0.16 * rect.width,
            y: rect.minY + 0.46 * rect.height,
            width: 0.68 * rect.width,
            height: 0.42 * rect.height
        )
        return Path(roundedRect: body, cornerRadius: 0.09 * rect.width, style: .continuous)
    }
}

struct EarnlyCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: p(0.36, 0.67))
        path.addLine(to: p(0.465, 0.765))
        path.addLine(to: p(0.65, 0.57))
        return path
    }
}

/// The Earnly brand mark, kept separate from standard SF Symbol iconography.
struct EarnlyLogo: View {
    enum Palette {
        /// Purple padlock with a mint checkmark.
        case color
        /// White padlock with a purple checkmark, for use on a purple field.
        case onBrand
    }

    var size: CGFloat = 48
    var palette: Palette = .color

    private var bodyColor: Color { palette == .color ? EarnlyColor.brand : .white }
    private var checkColor: Color { palette == .color ? EarnlyColor.success : EarnlyColor.brand }

    var body: some View {
        let stroke = StrokeStyle(lineWidth: size * 0.095, lineCap: .round, lineJoin: .round)
        ZStack {
            EarnlyShackleShape().stroke(bodyColor, style: stroke)
            EarnlyLockBodyShape().fill(bodyColor)
            EarnlyCheckShape().stroke(checkColor, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Earnly")
        .accessibilityAddTraits(.isImage)
    }
}

#Preview("Logo") {
    HStack(spacing: 24) {
        EarnlyLogo(size: 96)
        EarnlyLogo(size: 32)
        EarnlyLogo(size: 96, palette: .onBrand)
            .padding(16)
            .background(EarnlyColor.brand)
    }
    .padding()
    .background(EarnlyColor.canvas)
}
