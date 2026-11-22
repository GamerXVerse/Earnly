import SwiftUI

/// Screen 2: three-stage explanation as a continuous vertical sequence.
struct HowItWorksStep: View {
    private struct Stage: Identifiable {
        let id: Int
        let title: String
        let detail: String
    }

    private let stages = [
        Stage(id: 1, title: "Use your available screen time", detail: "Start each day with a short allowance for the apps you choose."),
        Stage(id: 2, title: "Practice when your allowance runs out", detail: "Those apps pause. Open Earnly and answer practice questions."),
        Stage(id: 3, title: "Earn additional screen time", detail: "Finish a set to unlock more minutes, then get back to your apps."),
    ]

    var body: some View {
        OnboardingPage(title: "How Earnly works") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(stages) { stage in
                    HStack(alignment: .top, spacing: EarnlySpacing.md) {
                        VStack(spacing: 0) {
                            Text("\(stage.id)")
                                .font(.callout.weight(.bold).monospacedDigit())
                                .foregroundStyle(stage.id == stages.count ? EarnlyColor.onSuccess : EarnlyColor.onBrand)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(stage.id == stages.count ? EarnlyColor.success : EarnlyColor.brand)
                                )
                                .accessibilityHidden(true)
                            if stage.id != stages.count {
                                Rectangle().fill(EarnlyColor.outline).frame(width: 1.5)
                                    .frame(maxHeight: .infinity)
                                    .accessibilityHidden(true)
                            }
                        }
                        VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                            Text(stage.title).font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
                            Text(stage.detail).font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                        }
                        .padding(.bottom, stage.id == stages.count ? 0 : EarnlySpacing.xl)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(stage.id). \(stage.title). \(stage.detail)")
                }
            }
        }
    }
}

#Preview("How it works") {
    HowItWorksStep().background(EarnlyColor.canvas)
}
