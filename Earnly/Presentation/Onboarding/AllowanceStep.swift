import SwiftUI

/// Screen 4: starting allowance (10 or 15 minutes) and the reward rule.
struct AllowanceStep: View {
    @Environment(PreviewAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    private let options = [10, 15]

    var body: some View {
        OnboardingPage(
            title: "Set your starting allowance",
            subtitle: "Time you can spend in your selected apps before they pause."
        ) {
            VStack(alignment: .leading, spacing: EarnlySpacing.xxl) {
                HStack(spacing: EarnlySpacing.sm) {
                    ForEach(options, id: \.self) { minutes in
                        option(minutes)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Starting allowance")

                EarnlyDivider()

                VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                    EarnlySectionHeader("How you earn more")
                    HStack(alignment: .firstTextBaseline, spacing: EarnlySpacing.xs) {
                        Text("\(model.profile.rewardQuestions)")
                            .font(EarnlyFont.stat)
                        Text("questions")
                            .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                        Text("=").font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                        Text("+\(model.profile.rewardMinutes)")
                            .font(EarnlyFont.stat).foregroundStyle(EarnlyColor.successText)
                        Text("minutes")
                            .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                    }
                    .foregroundStyle(EarnlyColor.ink)
                    .accessibilityElement(children: .combine)
                    Text("This is the starting rule. It will become adjustable in a future update.")
                        .font(EarnlyFont.secondary)
                        .foregroundStyle(EarnlyColor.inkSecondary)
                }
            }
        }
    }

    private func option(_ minutes: Int) -> some View {
        let selected = model.profile.allowanceMinutes == minutes
        return Button {
            EarnlyHaptics.selection()
            earnlyWithAnimation(reduceMotion: reduceMotion, EarnlyMotion.standard) {
                model.profile.allowanceMinutes = minutes
            }
        } label: {
            VStack(spacing: EarnlySpacing.xxs) {
                Text("\(minutes)").font(EarnlyFont.stat).foregroundStyle(EarnlyColor.ink)
                Text("minutes").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background {
                let shape = RoundedRectangle(cornerRadius: EarnlyGeometry.radiusControl, style: .continuous)
                ZStack {
                    shape.fill(EarnlyColor.surface)
                    shape.strokeBorder(EarnlyColor.outline, lineWidth: EarnlyGeometry.hairline)
                    if selected {
                        shape.fill(EarnlyColor.brandTint)
                            .overlay(shape.strokeBorder(EarnlyColor.brand, lineWidth: EarnlyGeometry.selectedBorder))
                            .matchedGeometryEffect(id: "allowanceSelection", in: selectionNamespace)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EarnlyColor.brandText)
                        .padding(EarnlySpacing.xs)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes) minutes")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview("Allowance") {
    AllowanceStep()
        .environment(PreviewAppModel())
        .background(EarnlyColor.canvas)
}
