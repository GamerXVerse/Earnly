import SwiftUI

/// Screen 3: choose one or more exams. AP expands into individual exams.
struct ExamSelectionStep: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var apExpanded = false

    var body: some View {
        OnboardingPage(
            title: "What are you preparing for?",
            subtitle: "Choose as many as you like. You can change this later."
        ) {
            VStack(spacing: EarnlySpacing.sm) {
                ForEach([PreviewExam.sat, .psat, .act]) { exam in
                    EarnlySelectionRow(
                        title: exam.title,
                        subtitle: exam.subtitle,
                        isSelected: model.profile.selectedExams.contains(exam)
                    ) {
                        model.profile.toggle(exam)
                    }
                }
                apCategory
            }
        }
    }

    private var apCategory: some View {
        let count = model.profile.selectedAPSubjects.count
        return VStack(spacing: EarnlySpacing.xs) {
            Button {
                EarnlyHaptics.selection()
                earnlyWithAnimation(reduceMotion: reduceMotion, EarnlyMotion.standard) { apExpanded.toggle() }
            } label: {
                HStack(spacing: EarnlySpacing.md) {
                    VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                        Text("AP").font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
                        Text(count == 0 ? "Choose individual exams" : "\(count) selected")
                            .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                    }
                    Spacer(minLength: EarnlySpacing.xs)
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(EarnlyColor.inkSecondary)
                        .rotationEffect(.degrees(apExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, EarnlySpacing.md)
                .padding(.vertical, EarnlySpacing.sm)
                .frame(maxWidth: .infinity, minHeight: EarnlyGeometry.minTouchTarget + EarnlySpacing.xs, alignment: .leading)
                .earnlyOutlined(selected: count > 0)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(count > 0 ? .isSelected : [])
            .accessibilityHint(apExpanded ? "Collapses the AP exam list" : "Expands the AP exam list")

            if apExpanded {
                VStack(spacing: EarnlySpacing.xs) {
                    ForEach(PreviewAPSubject.allCases) { subject in
                        EarnlySelectionRow(
                            title: subject.rawValue,
                            isSelected: model.profile.selectedAPSubjects.contains(subject)
                        ) {
                            model.profile.toggle(subject)
                        }
                    }
                }
                .padding(.leading, EarnlySpacing.md)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#if DEBUG
#Preview("Exam selection") {
    ExamSelectionStep()
        .environment(AppModel(service: DevelopmentScreenTimeService(), defaults: nil))
        .background(EarnlyColor.canvas)
}
#endif
