import SwiftUI

/// Screen 1: brand introduction.
struct IntroStep: View {
    private let topInset: CGFloat = 64

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.xxl) {
                VStack(alignment: .leading, spacing: EarnlySpacing.md) {
                    EarnlyLogo(size: 88)
                    EarnlyWordmark(size: 34)
                }
                // Hero lags the scroll by a few points; off with Reduce Motion.
                .earnlyParallax(distance: 12, restingY: topInset)

                VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                    Text("Your screen time. Earned.")
                        .font(EarnlyFont.pageTitle)
                        .foregroundStyle(EarnlyColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Keep the apps you like. Answer practice questions for the SAT, ACT, and AP exams to earn more time when your allowance runs out.")
                        .font(EarnlyFont.body)
                        .foregroundStyle(EarnlyColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, EarnlySpacing.screenMargin)
            .padding(.top, topInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.always)
    }
}

#Preview("Intro") {
    IntroStep().background(EarnlyColor.canvas)
}
