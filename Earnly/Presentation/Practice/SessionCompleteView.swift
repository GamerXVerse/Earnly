import SwiftUI

/// Completion: a restrained reward moment. Mint marks the earned time only.
struct SessionCompleteView: View {
    let session: PreviewPracticeSession
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                    EarnlyLogo(size: 56)
                        .padding(.top, EarnlySpacing.xxl)

                    VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                        Text("Session complete")
                            .font(EarnlyFont.titleMedium)
                            .foregroundStyle(EarnlyColor.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(session.correctCount) of \(session.total) answered correctly")
                            .font(EarnlyFont.body)
                            .foregroundStyle(EarnlyColor.inkSecondary)
                    }

                    VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                        Text("Time earned").earnlyOverline()
                        Text("+\(session.rewardMinutes) min")
                            .earnlyHeroNumber()
                            .foregroundStyle(EarnlyColor.ink)
                        Rectangle().fill(EarnlyColor.success).frame(height: 6)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)

                    EarnlyStatusMessage(
                        kind: .development,
                        text: "Demonstration reward. No time was added to a real allowance or removed from any restriction.")
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
            }
            .scrollBounceBehavior(.basedOnSize)

            EarnlyButton(title: "Back to Today", trailingSymbol: "arrow.right", action: onFinish)
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.top, EarnlySpacing.sm)
                .padding(.bottom, EarnlySpacing.md)
        }
    }
}

#Preview("Session complete") {
    let session = PreviewPracticeSession(startingAt: 9)
    session.select(0)
    session.submit()
    session.advance()
    return SessionCompleteView(session: session, onFinish: {})
        .background(EarnlyColor.canvas)
}
