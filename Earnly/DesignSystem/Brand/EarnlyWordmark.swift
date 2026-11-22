import SwiftUI

/// Lowercase `earnly.` wordmark in the brand purple.
struct EarnlyWordmark: View {
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1
    var size: CGFloat = 28
    var scalesWithDynamicType = true

    var body: some View {
        Text("earnly.")
            .font(.system(size: scalesWithDynamicType ? size * scale : size, weight: .bold))
            .tracking(-0.6)
            .foregroundStyle(EarnlyColor.brandText)
            .accessibilityLabel("Earnly")
            .accessibilityAddTraits(.isHeader)
    }
}

/// Mark plus wordmark.
struct EarnlyLockup: View {
    var markSize: CGFloat = 40
    var wordmarkSize: CGFloat = 32

    var body: some View {
        HStack(spacing: EarnlySpacing.xs) {
            EarnlyLogo(size: markSize)
            EarnlyWordmark(size: wordmarkSize)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Wordmark") {
    VStack(alignment: .leading, spacing: 24) {
        EarnlyWordmark()
        EarnlyLockup()
    }
    .padding()
    .background(EarnlyColor.canvas)
}
