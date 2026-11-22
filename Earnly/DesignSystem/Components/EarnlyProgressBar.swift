import SwiftUI

/// Flat progress bar. Value is clamped to 0...1.
struct EarnlyProgressBar: View {
    enum Tone { case brand, success }

    let value: Double
    var tone: Tone = .brand
    var accessibilityLabel: String = "Progress"

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(EarnlyColor.separator)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tone == .brand ? EarnlyColor.brand : EarnlyColor.success)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: EarnlyGeometry.progressHeight)
        .earnlyAnimation(EarnlyMotion.standard, value: clamped)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}

/// Segmented step indicator used by onboarding.
struct EarnlyStepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: EarnlySpacing.xxs) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index <= current ? EarnlyColor.brand : EarnlyColor.separator)
                    .frame(height: 4)
            }
        }
        .earnlyAnimation(EarnlyMotion.standard, value: current)
        .accessibilityElement()
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(current + 1) of \(total)")
    }
}

#Preview("Progress") {
    VStack(spacing: 24) {
        EarnlyProgressBar(value: 0.87)
        EarnlyProgressBar(value: 0.4, tone: .success)
        EarnlyStepIndicator(current: 2, total: 5)
    }
    .padding(24)
    .background(EarnlyColor.canvas)
}
