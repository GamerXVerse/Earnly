import SwiftUI

/// Selection experience shared by onboarding and Settings. The picker itself is supplied by the
/// service (Apple's FamilyActivityPicker in production); Earnly never enumerates installed apps.
struct ActivitySelectionPanel: View {
    @Environment(AppModel.self) private var model
    @State private var isPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
            content
            flowMessage
        }
        .sheet(isPresented: $isPickerPresented) {
            model.service.makeSelectionPicker { outcome in
                isPickerPresented = false
                Task { await model.handlePickerOutcome(outcome) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.snapshot?.authorization != .approved {
            EarnlyStatusMessage(kind: .warning, title: "Screen Time access is needed first",
                                text: "Earnly can only offer Apple's app picker once Screen Time access is on.")
        } else if let selection = model.snapshot?.selection, !selection.isEmpty {
            saved(selection)
        } else {
            empty
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.md) {
            Text("No apps chosen yet").font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
            Text("Earnly isn't monitoring anything until you choose. Apple's picker keeps your choices private to this device.")
                .font(EarnlyFont.body).foregroundStyle(EarnlyColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            caution
            chooseButton(title: "Choose apps")
        }
    }

    private func saved(_ selection: ActivitySelectionSummary) -> some View {
        VStack(alignment: .leading, spacing: EarnlySpacing.md) {
            VStack(alignment: .leading, spacing: EarnlySpacing.xxs) {
                Text("Selected").earnlyOverline()
                Text(selection.description).font(EarnlyFont.sectionHeading).foregroundStyle(EarnlyColor.ink)
            }
            if let labels = model.service.makeSelectionLabels() { labels }
            monitoringRow
            caution
            chooseButton(title: "Change selection", kind: .secondary)
        }
    }

    private var monitoringRow: some View {
        let status = model.monitoringStatus
        return EarnlyStatusMessage(
            kind: status.kind == .on ? .success : (status.kind == .pending ? .info : .warning),
            text: status.text)
    }

    private var caution: some View {
        Text("Choosing a whole category can include many apps. Pick only what pulls you away from studying.")
            .font(EarnlyFont.caption).foregroundStyle(EarnlyColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func chooseButton(title: String, kind: EarnlyButtonStyle.Kind = .primary) -> some View {
        EarnlyButton(title: model.selectionFlow == .applying ? "Saving…" : title, kind: kind) {
            model.clearSelectionFlow()
            isPickerPresented = true
        }
        .disabled(model.selectionFlow == .applying)
    }

    @ViewBuilder
    private var flowMessage: some View {
        switch model.selectionFlow {
        case .cancelled:
            Text("No changes made.").font(EarnlyFont.secondary).foregroundStyle(EarnlyColor.inkSecondary)
        case .empty:
            EarnlyStatusMessage(kind: .warning, title: "Nothing selected",
                                text: "Your previous setup is unchanged. Choose at least one app, category or website.")
        case .failed(let failure):
            EarnlyStatusMessage(kind: .warning, title: "Selection not saved", text: failure.userMessage)
        case .idle, .applying:
            EmptyView()
        }
    }
}
