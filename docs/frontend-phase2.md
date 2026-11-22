# Earnly Phase 2A: Frontend integration

Branch `agent/frontend`. Builds on `docs/frontend-phase1.md`. Visual identity is unchanged.

## Presentation architecture

```
Earnly/Integration/
  ScreenTimeModels.swift                 presentation value types (mirror systems concepts)
  ScreenTimeService.swift                ScreenTimeServicing protocol, ServiceFailure, DisconnectedScreenTimeService, factory
  DevelopmentScreenTimeService.swift     DEBUG only: deterministic adapter + fixtures
  AppModel.swift                         @Observable state: snapshot, in-flight requests, errors, explicit async actions
  DashboardPresentation.swift            pure snapshot -> Today state (unit tested)
  PracticeFlowModel.swift                drives one practice presentation from service responses
Earnly/Presentation/Shared/              AuthorizationPanel, ActivitySelectionPanel, AllowancePicker, MonitoringStatus
```

Views read `AppModel` only. They never import FamilyControls or `EarnlySystems`, and never decide that a restriction was applied, a reward granted or a session finished. All three come from the `ServiceSnapshot` returned by `ScreenTimeServicing`.

`reconcile()` is the single refresh call. It runs at launch and on every foreground entry (`ContentView`). A production adapter re-reads authorization, checks platform state, drives any pending operation and returns authoritative state. The release build uses `DisconnectedScreenTimeService`, which reports `.unavailable` and throws `.notConnected`; it never simulates success. The dev adapter and all dev UI are inside `#if DEBUG` (a Release build was compiled to confirm).

The systems package could not be linked here (it lives in another worktree and `project.yml` package wiring belongs to the systems integration), so the boundary is a protocol with a deterministic adapter. No second production implementation exists.

## Production integration points (for the systems adapter)

Implement `ScreenTimeServicing` by wrapping `EarnlySystem` plus the platform coordinator, then return it from `ScreenTimeServiceFactory.make`.

| Boundary member | Maps to |
| --- | --- |
| `snapshot()` / `reconcile()` | `dashboard()`, `handle(.authorizationChanged)`, `pendingOperation()` + coordinator effects, `reconcileShield()` |
| `requestAuthorization()` | `ScreenTimeAuthorizing.requestAuthorization()`, then `handle(.authorizationChanged)` even on throw |
| `makeSelectionPicker` | Adapter-hosted `FamilyActivityPicker`; returns `ActivitySelectionSummary` keyed to stored tokens |
| `makeSelectionLabels` | Adapter-hosted token `Label` views (nil until implemented) |
| `applySelection` | `configure(policy:selection:)` or `replaceRevokedSelection(_:)`, then `installMonitoring` |
| `updateAllowance` | `checkConfigurationReset`, stop monitoring, clear shield, `resetConfiguration(policy:)`, `configure` |
| `disableRestrictions` | `stopMonitoring`, `removeShield`, `resetConfiguration` (history kept) |
| `startPractice` / `submitAnswer` | `PracticeSessionManaging` (start returns the active session = resume) |
| `grantReward` | `RewardManaging.grantReward(for:)` (idempotent per session) |
| `retryPendingOperation` | `retryPendingOperation()` + coordinator re-run; must not touch the ledger |

Snapshot mapping: `RestrictionState` -> `LifecycleStage`; `.failed(.shield)` with an unactivated credit -> `pendingReward.releaseFailed = true`; credit `activatedAt` set in the current cycle -> `releasedRewardMinutes`; `remainingMinutes` stays nil (systems reports `.unavailable`); `mostRecentThresholdMinutes` -> `thresholdEvidenceMinutes`; ledger + sessions -> `rewardHistory`. `PreviewStudyProfile` exams map to `StudyProfile`/`ExamType`.

## Behavior

- **Authorization**: states not requested, requesting, authorized, denied, revoked, unavailable, failed. "Authorized" shows only after the service confirms. A decided state never re-prompts; the UI offers iOS Settings. Users can exit and continue without access. Copy does not claim restrictions are impossible to bypass.
- **Selection**: same panel in onboarding (step 6) and Settings. Handles cancel, empty result (rejected without a service call), saved selection, change, and failure. Monitoring is described as on only when the snapshot says so.
- **Allowance**: 10/15 minutes via one shared picker. Required questions and reward minutes are separate policy values. A change shows "Applying…" and any systems error (for example configuration locked mid-practice).
- **Today**: prioritized state from `DashboardPresentation`. Without a measurement the hero reads "10 min / Configured allowance. Remaining time isn't measured." No timers or countdowns.
- **Routing**: `AppRouter.routeOnActivation` presents an unfinished session once per session ID, lands on Today for a restricted state with no session once per cycle, and never re-presents or moves tabs on repeat activations.
- **Practice**: question identity, answers, correctness and completion come from the service; submit is disabled while in flight; progress resumes. Incorrect answers show an explanation only.
- **Reward**: "Time earned. Restoring access." until release is confirmed. On failure the reward stays, "Try again" calls `retryPendingOperation` (no second credit). Success shows the mint bar, brand mark and a success haptic on the transition to released. A complete session whose credit was never recorded is finalized on the next reconcile.
- **Progress**: ledger-based minutes earned per day and recent sets. "Time used" reads "Not measured".
- **Settings**: access, selected apps, allowance, reward rule, monitoring status and "Turn off restrictions" (confirmation, failure shown). Development tools exist in DEBUG only.

## Shield specification (for the systems agent's extensions)

- Title: "Time to earn it."
- Subtitle: "Complete your practice questions in Earnly to unlock more screen time."
- Colors: solid #6155F5 primary button with white text, neutral background (light #F6F7FB / dark #141422), no gradients. Earnly mark if the configuration API allows an icon.
- Primary label "Open Earnly" only if the shield action can actually open Earnly on that OS and authorization configuration; otherwise "Close app" with the subtitle explaining that the student must return to Earnly. Phase 2A makes no assumption that a deep link works: manual launch reconciles into the same Today/practice path.

## Unresolved integration issues

1. `startPractice` requires approved authorization and a restricted stage, so there is no unrewarded practice mode. The Practice tab says so. If ungated practice is wanted, systems must add it.
2. No pause/resume in the systems API; "Turn off" resets configuration and requires reselecting apps.
3. Shield-failure while applying (not releasing) has no distinct credit state; shown as a generic restriction failure.
4. Package linking in `project.yml` is pending.
5. Onboarding completion is a frontend `UserDefaults` flag, and exam choices are not yet persisted.

## Verification

Simulator (iPhone 17 Pro, Xcode 26.6, dev adapter): Debug build and Release build succeed; 29 unit tests and 5 UI tests pass (onboarding progression, auth rendering and no re-prompt, selection cancel/empty, repeated activation, interrupted practice, duplicate submit, reward retry single-credit, unsupported remaining usage, restricted/practice/release-failure flows). Screenshots reviewed in light mode: Today restricted (revised to match the Phase 2 target: brand mark, headline, facts, one action), release failure, authorization denied. The revised reward-complete, allowance (radio rows + Save) and selection screens follow the target layout but were not screenshot-reviewed. Not reviewed: dark mode, onboarding authorization/selection screens, reward success, Settings, small devices, large Dynamic Type, VoiceOver, Reduce Motion.

Not verified: real Screen Time authorization, FamilyActivityPicker, monitoring, shields, extensions, or any physical-device behavior.

## Recommendations for Phase 3

Question-bank expansion; persist profile and onboarding via systems; accessibility audit on device; pause/resume policy; real `FamilyActivityPicker` label rendering; snapshot-style UI tests for dark mode.
