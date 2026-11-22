import SwiftUI

/// 10 or 15 minute allowance. Used by onboarding and Settings so both edit the same value.
/// A change on a configured policy is shown as pending until the service confirms it.
struct AllowancePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
            HStack(spacing: EarnlySpacing.sm) {
                ForEach(PolicySummary.allowanceOptions, id: \.self) { minutes in option(minutes) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Starting allowance")
            changeStatus
        }
    }

    @ViewBuilder
    private var changeStatus: some View {
        switch model.change {
        case .idle: EmptyView()
        case .applying(let text):
            Text("\(text)…").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        case .failed(let failure):
            EarnlyStatusMessage(kind: .warning, title: "Allowance not changed", text: failure.userMessage)
        }
    }

    private func option(_ minutes: Int) -> some View {
        let selected = model.displayedAllowance == minutes
        let busy: Bool = { if case .applying = model.change { return true } else { return false } }()
        return Button {
            EarnlyHaptics.selection()
            Task { await model.setAllowance(minutes: minutes) }
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
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                        .foregroundStyle(EarnlyColor.brandText).padding(EarnlySpacing.xs)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .earnlyAnimation(EarnlyMotion.standard, value: selected)
        .accessibilityLabel("\(minutes) minutes")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Reward rule from policy. Questions and minutes are separate values.
struct RewardRuleSummary: View {
    let policy: PolicySummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: EarnlySpacing.xs) {
            Text("\(policy.requiredQuestions)").font(EarnlyFont.stat)
            Text("questions").font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
            Text("=").font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
            Text("+\(policy.rewardMinutes)").font(EarnlyFont.stat).foregroundStyle(EarnlyColor.successText)
            Text("minutes").font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
        }
        .foregroundStyle(EarnlyColor.ink)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(policy.requiredQuestions) questions earn \(policy.rewardMinutes) minutes")
    }
}
