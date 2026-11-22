import SwiftUI
import Charts

/// Progress from verified reward records only. Minutes earned and measured use are different
/// values: earned comes from the ledger, and use is not measured by the platform.
struct ProgressOverviewView: View {
    @Environment(AppModel.self) private var model

    private var history: [RewardEntry] { model.snapshot?.rewardHistory ?? [] }

    private struct DayTotal: Identifiable {
        let day: Date
        let minutes: Int
        var id: Date { day }
    }

    private var days: [DayTotal] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: history) { cal.startOfDay(for: $0.earnedAt) }
        return grouped.map { DayTotal(day: $0.key, minutes: $0.value.map(\.minutes).reduce(0, +)) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Progress").font(EarnlyFont.pageTitle).foregroundStyle(EarnlyColor.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        if model.isSimulated { EarnlyPreviewTag(text: "Simulated") }
                    }
                    if history.isEmpty { emptyState } else { content }
                }
                .padding(.horizontal, EarnlySpacing.screenMargin)
                .padding(.top, EarnlySpacing.md)
                .padding(.bottom, EarnlySpacing.xl)
            }
            .background(EarnlyColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xl) {
            HStack(alignment: .top, spacing: EarnlySpacing.xl) {
                metric("\(model.snapshot?.earnedMinutes ?? history.map(\.minutes).reduce(0, +))m", "Time earned")
                metric("\(history.count)", "Sets completed")
                metric("Not measured", "Time used")
            }

            VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
                EarnlySectionHeader("Minutes earned per day")
                Chart(days) { day in
                    BarMark(x: .value("Day", day.day, unit: .day), y: .value("Minutes earned", day.minutes))
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
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated)).foregroundStyle(EarnlyColor.inkSecondary)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("Minutes earned per day")
                .accessibilityValue(days.map { "\($0.day.formatted(.dateTime.weekday(.wide))) \($0.minutes) minutes" }.joined(separator: ", "))
                Text("Earned time comes from completed sets. Earnly can't measure how much of it you've used.")
                    .font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
            }

            EarnlyDivider()

            VStack(alignment: .leading, spacing: 0) {
                EarnlySectionHeader("Recent sets").padding(.bottom, EarnlySpacing.xs)
                ForEach(history.sorted { $0.earnedAt > $1.earnedAt }) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                            Text(entry.earnedAt.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(EarnlyFont.bodyEmphasis).foregroundStyle(EarnlyColor.ink)
                            Text("\(entry.correct) of \(entry.total) correct")
                                .font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
                        }
                        Spacer()
                        Text("+\(entry.minutes) min").font(EarnlyFont.bodyEmphasis.monospacedDigit())
                            .foregroundStyle(EarnlyColor.successText)
                    }
                    .padding(.vertical, EarnlySpacing.sm)
                    .frame(minHeight: EarnlyGeometry.minTouchTarget)
                    .accessibilityElement(children: .combine)
                    EarnlyDivider()
                }
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
            Text(value).font(EarnlyFont.stat).foregroundStyle(value == "Not measured" ? EarnlyColor.inkSecondary : EarnlyColor.ink)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.md) {
            Text("No practice yet").font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
            Text("Finish your first set and your earned time will show up here.")
                .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, EarnlySpacing.md)
    }
}

#if DEBUG
#Preview("Progress: history") {
    let model = AppModel(service: DevelopmentScreenTimeService(fixture: .allowanceActiveWithHistory, latency: .zero), defaults: nil)
    return ProgressOverviewView().environment(model).task { await model.refreshSnapshot() }
}
#Preview("Progress: empty") {
    ProgressOverviewView().environment(AppModel(service: DevelopmentScreenTimeService(fixture: .allowanceActive, latency: .zero), defaults: nil))
}
#endif
