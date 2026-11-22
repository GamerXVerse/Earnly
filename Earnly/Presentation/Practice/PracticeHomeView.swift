import SwiftUI

/// Practice tab: start a set. Sessions run full screen.
struct PracticeHomeView: View {
    @Environment(PreviewAppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                    Text("Practice")
                        .font(EarnlyFont.pageTitle)
                        .foregroundStyle(EarnlyColor.ink)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
                        Text("Next set").earnlyOverline()
                        Text("\(model.profile.rewardQuestions) questions")
                            .font(EarnlyFont.titleMedium).foregroundStyle(EarnlyColor.ink)
                        Text("Finish the set to earn \(model.profile.rewardMinutes) minutes of screen time.")
                            .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    EarnlyButton(title: "Start practice", trailingSymbol: "arrow.right") { router.startPractice() }

                    EarnlyDivider()

                    VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                        EarnlySectionHeader(title: "Preparing for") {
                            Button("Edit") { router.open(.exams) }
                                .font(EarnlyFont.secondaryEmphasis)
                                .foregroundStyle(EarnlyColor.brandText)
                                .frame(minHeight: EarnlyGeometry.minTouchTarget)
                        }
                        Text(model.profile.examSummary)
                            .font(EarnlyFont.body).foregroundStyle(EarnlyColor.ink)
                    }

                    EarnlyStatusMessage(
                        kind: .development,
                        text: "Questions are original sample content for this prototype. Real question sets arrive in a later phase.")
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.top, EarnlySpacing.md)
                .padding(.bottom, EarnlySpacing.xl)
            }
            .background(EarnlyColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Practice home") {
    PracticeHomeView()
        .environment(PreviewAppModel.previewMain)
        .environment(AppRouter())
}
