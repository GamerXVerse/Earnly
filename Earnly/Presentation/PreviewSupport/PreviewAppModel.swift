import Foundation
import Observation

/// Shared presentation state for the Phase 1 prototype.
///
/// Everything here is temporary and in-memory. Phase 2 replaces the stored
/// properties with values supplied by the systems agent's services; views only
/// depend on the properties and the callbacks listed below.
@Observable
final class PreviewAppModel {
    var profile: PreviewStudyProfile
    var hasCompletedOnboarding: Bool
    var authorization: PreviewAuthorizationState
    /// Development override for the Today screen. Not a production concept.
    var dashboardState: PreviewDashboardState
    /// Development override for the Progress screen empty state.
    var showsDemoProgress: Bool = true

    init(
        profile: PreviewStudyProfile = PreviewStudyProfile(),
        hasCompletedOnboarding: Bool = false,
        authorization: PreviewAuthorizationState = .notDetermined,
        dashboardState: PreviewDashboardState = .firstLaunchIncomplete
    ) {
        self.profile = profile
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.authorization = authorization
        self.dashboardState = dashboardState
    }

    var restriction: PreviewRestrictionState {
        .make(for: dashboardState, profile: profile)
    }

    // MARK: Callbacks (integration seams)

    /// Phase 2: forward to the Screen Time authorization service and set `authorization` from its result.
    /// Phase 1: only simulates, and the UI labels the result as development mode.
    func requestAuthorization(simulating result: PreviewAuthorizationState = .simulatedGranted) {
        authorization = result
    }

    /// Phase 2: persist the profile through the systems layer, then enter the app.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        dashboardState = authorization == .simulatedGranted ? .available : .authorizationUnavailable
    }

    func restartOnboarding() {
        profile = PreviewStudyProfile()
        authorization = .notDetermined
        dashboardState = .firstLaunchIncomplete
        hasCompletedOnboarding = false
    }

    func finishPractice() {
        dashboardState = .earned
    }

    // MARK: Samples

    static var previewMain: PreviewAppModel {
        PreviewAppModel(
            profile: .sample, hasCompletedOnboarding: true,
            authorization: .simulatedGranted, dashboardState: .available)
    }
}
