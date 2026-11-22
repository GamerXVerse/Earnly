import SwiftUI
import UIKit

/// Motion tokens. Durations stay between 150 and 350 ms.
enum EarnlyMotion {
    static let quick = Animation.easeOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let emphasized = Animation.easeInOut(duration: 0.32)
}

/// Thin wrapper over UIKit feedback generators.
enum EarnlyHaptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

private struct MotionAwareAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

private struct SubtleParallax: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let distance: CGFloat
    let restingY: CGFloat

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            // The view lags the scrolling content by 15%, capped at `distance`.
            // visualEffect runs off the layout pass, so it adds no layout work.
            content.visualEffect { [distance, restingY] view, proxy in
                let minY = proxy.frame(in: .scrollView).minY
                let delta = max(-distance, min(distance, (restingY - minY) * 0.15))
                return view.offset(y: delta)
            }
        }
    }
}

extension View {
    /// `animation(_:value:)` that is skipped when Reduce Motion is on.
    func earnlyAnimation<V: Equatable>(_ animation: Animation = EarnlyMotion.standard, value: V) -> some View {
        modifier(MotionAwareAnimation(animation: animation, value: value))
    }

    /// Scroll-linked offset of at most `distance` points (6–16). Disabled by Reduce Motion.
    /// `restingY` is the view's top edge inside the scroll view when at rest.
    func earnlyParallax(distance: CGFloat = 12, restingY: CGFloat = 0) -> some View {
        modifier(SubtleParallax(distance: min(max(distance, 6), 16), restingY: restingY))
    }
}

/// Runs `body` inside `withAnimation` unless Reduce Motion is on.
@MainActor
func earnlyWithAnimation(reduceMotion: Bool, _ animation: Animation = EarnlyMotion.standard, _ body: () -> Void) {
    if reduceMotion { body() } else { withAnimation(animation, body) }
}
