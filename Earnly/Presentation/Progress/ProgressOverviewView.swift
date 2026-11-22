import SwiftUI
import Charts

/// Progress: one chart that shows a real relationship (practice volume by day),
/// then per-exam accuracy. Demo data is always labeled.
struct ProgressOverviewView: View {
    @Environment(PreviewAppModel.self) private var model
    @Environment(AppRouter.self) private var router

    private var data: PreviewProgressData { model.showsDemoProgress ? .demo : .empty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Progress")
                            .font(EarnlyFont.pageTitle).foregroundStyle(EarnlyColor.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        if model.showsDemoProgress { EarnlyPreviewTag() }
                    }

                    if data.week.isEmpty {
                        emptyState
                    } else {
                        content
                    }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.top, EarnlySpacing.md)
                .padding(.bottom, EarnlySpacing.xl)
            }
            .background(EarnlyColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PreviewExamPerformance.ID.self) { id in
                if let item = data.performance.first(where: { $0.id == id }) {
                    ExamPerformanceDetail(item: item)
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
            HStack(alignment: .top, spacing: EarnlySpacing.xl) {
                metric("\(data.totalQuestions)", "Questions this week")
                metric("\(Int((data.overallAccuracy * 100).rounded()))%", "Accuracy")
                metric("\(data.minutesEarned)m", "Time earned")
            }

            VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                EarnlySectionHeader("Questions per day")
                Chart(data.week) { day in
                    BarMark(x: .value("Day", day.day), y: .value("Questions", day.questions))
                        .foregroundStyle(EarnlyColor.brand)
                        .cornerRadius(2)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(EarnlyColor.separator)
                        AxisValueLabel().foregroundStyle(EarnlyColor.inkSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(EarnlyColor.inkSecondary) }
                }
                .frame(height: 180)
                .accessibilityLabel("Questions completed per day this week")
                .accessibilityValue(data.week.map { "\($0.day) \($0.questions)" }.joined(separator: ", "))
            }

            EarnlyDivider()

            VStack(alignment: .leading, spacing: 0) {
                EarnlySectionHeader("By exam section")
                    .padding(.bottom, EarnlySpacing.xs)
                ForEach(data.performance) { item in
                    NavigationLink(value: item.id) {
                        PerformanceRow(item: item)
                    }
                    .buttonStyle(.plain)
                    EarnlyDivider()
                }
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
            Text(value).font(EarnlyFont.stat).foregroundStyle(EarnlyColor.ink)
            Text(label).font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.md) {
            Text("No practice yet").font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
            Text("Finish your first set and your questions, accuracy, and earned time will show up here.")
                .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            EarnlyButton(title: "Start practice", trailingSymbol: "arrow.right") { router.startPractice() }
        }
        .padding(.top, EarnlySpacing.md)
    }
}

private struct PerformanceRow: View {
    let item: PreviewExamPerformance

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xs) {
            HStack {
                Text(item.name).font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
                Spacer()
                Text("\(Int((item.accuracy * 100).rounded()))%")
                    .font(EarnlyFont.bodyEmphasis.monospacedDigit()).foregroundStyle(EarnlyColor.ink)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(EarnlyColor.inkSecondary).accessibilityHidden(true)
            }
            EarnlyProgressBar(value: item.accuracy, accessibilityLabel: "\(item.name) accuracy")
            Text("\(item.questionsCompleted) questions")
                .font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
        }
        .padding(.vertical, EarnlySpacing.sm)
        .frame(minHeight: EarnlyGeometry.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct ExamPerformanceDetail: View {
    let item: PreviewExamPerformance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                Text("Accuracy").earnlyOverline()
                Text("\(Int((item.accuracy * 100).rounded()))%").earnlyHeroNumber()
                    .foregroundStyle(EarnlyColor.ink)
                Text("\(item.questionsCompleted) questions completed")
                    .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                EarnlyStatusMessage(kind: .development, text: "Skill-level breakdowns arrive in a later phase. These numbers are sample data.")
            }
            .padding(EarnlySpacing.screenMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EarnlyColor.canvas)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Progress: demo") {
    ProgressOverviewView()
        .environment(PreviewAppModel.previewMain)
        .environment(AppRouter())
}

#Preview("Progress: empty") {
    let model = PreviewAppModel.previewMain
    model.showsDemoProgress = false
    return ProgressOverviewView().environment(model).environment(AppRouter())
}
