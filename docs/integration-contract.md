# Frontend integration contract

Open the systems worktree's `Package.swift` in Xcode to work on its library and tests. In the Earnly app project, add the repository root as a local package and link the `EarnlySystems` product to the app target. The manifest lists the systems source directories explicitly. If the app uses filesystem-synchronized groups, exclude those directories from direct app-target membership so the app imports a single copy. Register frontend files through the app project normally. Qualify names such as `EarnlySystems.PracticeSession` if a preview already uses a matching short name.

The frontend project uses XcodeGen. At integration, add the local package to the top-level `packages` section in `project.yml` and add a package dependency to the app. Keep the existing sources and settings. In the application source entry, exclude the five systems directories. In the `EarnlyTests` source entry, exclude `Domain`, `Services` and `Infrastructure` so those tests run through the package scheme. Regenerate the project after updating `project.yml`. Use this structure for the package declaration and app dependency.

```yaml
packages:
  EarnlySystems:
    path: .
targets:
  Earnly:
    dependencies:
      - package: EarnlySystems
        product: EarnlySystems
```

Create one `EarnlySystem` per Application Support file. The view model owns a `DashboardStatus`, beginning with `.loading`, then assigns `.ready(await system.dashboard())` or `.failed(PersistenceError)` on its main actor. Reuse the actor across views. Use separate files for simulated and observed modes. On app start and foreground entry, feed the latest authorization result to `handle(.authorizationChanged(status))` and reconcile the platform before enabling restrictions or rewards. In Phase 1, use the simulated adapter in app flows.

## Interfaces

Protocol members shown below are callable from a main-actor view model. Actor calls use `await`. The Apple authorization adapter is main-actor isolated and should be invoked from a deliberate user action. `QuestionProviding` is synchronous and `Sendable` because the Phase 1 catalog is local and static.

| Swift type | Methods and behavior |
| --- | --- |
| `ScreenTimeAuthorizing` | `authorizationState() async -> AuthorizationState`, `requestAuthorization() async throws -> AuthorizationState`. The request returns approval or a typed `ScreenTimeServiceError`. Record status again even after the request throws. |
| `ActivitySelectionProviding` | `loadSelection() async throws -> ActivitySelection?`, `saveSelection(_:) async throws`, `clearSelection() async throws`. An empty platform selection should be cleared or rejected. The Phase 2 picker captures Apple objects inside the adapter and emits a summary keyed to its stored tokens. |
| `UsageMonitoring` | `installMonitoring(for:selection:) async throws`, `stopMonitoring(cycleID:) async throws`, `thresholdEvents() async -> AsyncStream<UsageThresholdEvent>`. Events carry a cycle ID and receipt timestamp. A live stream in Phase 2 can be fed by the durable extension inbox. |
| `RestrictionControlling` | `applyShield(for:cycleID:) async throws`, `removeShield(cycleID:) async throws`, `reconcileShield() async throws -> ShieldStatus`. The result describes the app's managed store. Check the desired state and generation before issuing an effect. |
| `QuestionProviding` | `questions(for:count:) throws -> [EarnlyQuestion]`. `DemoQuestions` returns up to the requested count in stable order. A difficulty preference changes ordering. A filter with insufficient items is surfaced by `startPractice()`. The full default demo uses SAT or an empty exam selection. PSAT, ACT, AP Calculus AB and AP Statistics have illustrative items only. |
| `PracticeSessionManaging` | `startPractice() async throws -> PracticeSession`, `session(id:) async throws -> PracticeSession`, `submitAnswer(sessionID:questionID:answerID:) async throws -> PracticeSession`. Starting again returns the active session. Submit stable IDs. Use `answeredQuestions`, `correctAnswers` and `isComplete` to render progress and results. |
| `RewardManaging` | `grantReward(for:) async throws -> RewardTransaction`, `rewardLedger() async -> RewardLedger`. Grant after a complete session even when authorization is unavailable. A repeat returns the current credit, including subsequent activation and threshold evidence. |
| `ProfilePersisting` | `studyProfile() async -> StudyProfile`, `saveStudyProfile(_:) async throws`. The stored value is returned on the next launch. |
| `SharedThresholdInbox` | `appendThreshold(_:) async throws`, `pendingThresholds() async throws -> [UsageThresholdEvent]`, `acknowledgeThreshold(cycleID:) async throws`. The implementation belongs to Phase 2. Acknowledgment follows committed consumption of the receipt. |

## Driving the lifecycle

`EarnlySystem(fileURL:questions:provenance:now:)` throws a `PersistenceError` at startup. `dashboard() -> DashboardSnapshot` and `pendingOperation() -> RestrictionOperation?` are actor-isolated. `configure(policy:selection:) throws -> UsageCycle` requires approval, a nonempty selection and an enabled policy. To change settings, serialize the operation, call `checkConfigurationReset()` and get the generation from `currentCycle()`. Retire the previous registration and clear its shield, then call `resetConfiguration(policy:)` and configure again. Finish a pending completed session's reward before resetting. Use `replaceRevokedSelection(_:) throws` after new approval and a replacement selection. It may emit a shield application before allowing practice to resume.

A single coordinator should drive platform effects. Re-read the pending operation before effect execution and serially confirm success with `handle(_:)`. Recover effects on launch by checking whether the matching registration or shield change already took effect. Keep stale asynchronous operations from modifying a newer generation. Development code can drive the same sequence directly.

```swift
import EarnlySystems
import Foundation

func configureDemo(fileURL: URL) async throws -> (EarnlySystem, SimulatedScreenTime, UsageCycle) {
    let platform = SimulatedScreenTime()
    let system = try EarnlySystem(fileURL: fileURL, provenance: .simulated)
    let status = try await platform.requestAuthorization()
    try await system.handle(.authorizationChanged(status))

    let selection = ActivitySelection(
        id: UUID(), applicationCount: 1, categoryCount: 0, webDomainCount: 0
    )
    try await platform.saveSelection(selection)
    let cycle = try await system.configure(policy: .standard, selection: selection)
    try await platform.installMonitoring(for: cycle, selection: selection)
    try await system.handle(.monitoringInstalled(cycleID: cycle.id))
    try await platform.removeShield(cycleID: cycle.id)
    try await system.handle(.accessReleased(cycleID: cycle.id))
    return (system, platform, cycle)
}
```

The example configures a fresh demo file. `SimulatedScreenTime` stores its settings in memory. A demo that reopens a persisted file must reconcile or rehydrate its simulated platform separately. To simulate threshold arrival, subscribe to `thresholdEvents()` before calling `emitThreshold(_:)`, pass the event into `receiveThreshold(_:)`, apply any returned shield operation, then confirm it with `.shieldApplied(cycleID:)`. The core callback handler tolerates stale and duplicate generations. An early callback exposes `.failed(.thresholdBeforeRelease)` and must trigger platform cleanup before retry. After practice completion, call `grantReward(for:)`. Drive the new `.installMonitoring` and `.releaseShield` operations with their new cycle ID, as in the setup example.

For expected adapter failures, record `.operationFailed(cycleID: id, .monitoring)` or `.operationFailed(cycleID: id, .shield)` using the actual operation ID. Use `retryPendingOperation()` after diagnosing the failure and checking authorization. When refreshing authorization fails transiently, a current threshold receipt stays pending until approval can be verified. Use `DashboardValue` provenance to label simulated values appropriately. `remainingMinutes` is `.unavailable`. A threshold evidence value represents a lower bound for one eligibility cycle. Render it separately from remaining time.

`LifecycleError` distinguishes permission, invalid selection, disabled policy, locked configuration, invalid transitions and damaged credit references. `PracticeError` distinguishes missing or invalid question sets, unknown sessions and submissions, conflicting duplicates and incomplete sessions. `RewardError.ledgerCapacityExceeded` is an accounting overflow guard. `PersistenceError` distinguishes corruption, unknown schema, inconsistent records, unreadable files and write failures. Preserve the last successful snapshot on a failed write and show retry or recovery state. Expected screen labels belong in the app's presentation layer.

## Phase 2 native host interface

On iOS, import `EarnlySystems` and `FamilyControls`. Create one `@MainActor AppleScreenTimeEngine` from the real registered group, the current host bundle identifier, and a private Application Support URL. Call `appDidBecomeActive() async throws` on initial activation and each return to the active scene. This also recovers valid completions left between the last answer and the host credit commit. Serialize user commands in the view model. The coordinator rejects overlapping host commands with `ScreenTimeServiceError.operationInProgress`.

| API | Frontend use |
| --- | --- |
| `init(fileURL:appGroupIdentifier:hostBundleIdentifier:) throws` | Create once per host. Group access and learning file failures are explicit. Use a separate file for simulation. |
| `requestAuthorization() async throws -> AuthorizationState` | Call from an explicit user gesture. Denial, revocation and unexpected request failures can throw. Read the reconciled dashboard after either outcome. |
| `pickerSelection() throws -> FamilyActivitySelection` | Copy the current Apple selection to an editable draft. Present Apple's picker with a binding. Cancel by discarding the draft. |
| `configure(policy:selection:) async throws` | Submit a confirmed draft with an enabled policy. The native Apple adapter validates scope before changing any running policy. It rejects unsupported OS, empty selection, categories and app selections for which it cannot verify self-exclusion. Approved but invalidated selection can resume a suspended lifecycle with its original terms. |
| `system.startPractice() async throws -> PracticeSession` and `system.submitAnswer(sessionID:questionID:answerID:) async throws -> PracticeSession` | Reuse Phase 1 logic and expose practice for eligible states. The last valid answer completes the session. Use `isComplete` to present completion. |
| `finishPractice(sessionID:) async throws -> RewardTransaction` | Validates persisted completion and commits a single credit, then drives the platform operations. An operational error can occur after the credit was written. Refresh the dashboard and ledger, then present retry or pending state. |
| `retry() async throws` | Replays durable pending registration, release, or cleanup. A monitoring interruption can return `LifecycleError.configurationLocked` when the amount consumed became unknown. Offer explicit disablement and reconfiguration there. |
| `disable() async throws` | Fences callbacks first, stops only Earnly registrations, and clears only Earnly's store. A partial failure exposes `.cleanupPending`. A completed unactivated reward survives cleanup and can resume on later setup. |
| `dashboard() async -> NativeDashboard` | Read `dashboard` for confirmed authorization, policy, practice and credit data. Use `monitoring` for current checked registration, pending, shielded, unavailable, interrupted or cleanup presentation. Only `.registered` supports “Allowance active.” Remaining usage stays unavailable. |

The host can observe either a shielded or pending state when it returns from an extension and route inside Earnly accordingly. Earlier OS versions and the default current shield action close the selected activity, and the user then opens Earnly. The package's internal `ScreenTimeCoordinator` owns lifecycle effects. Use the raw Phase 1 platform commands only in deterministic development flows. Native UI code can use the existing practice and profile APIs on `engine.system`.

```swift
let engine = try AppleScreenTimeEngine(
    fileURL: privateLearningFile,
    appGroupIdentifier: configuredGroup,
    hostBundleIdentifier: hostIdentifier
)
// The view model invokes this from scene activation.
try await engine.appDidBecomeActive()
// Present the system picker with a draft, then call this on confirmation.
try await engine.configure(policy: .standard, selection: confirmedDraft)
let state = await engine.dashboard()
```

Phase 1 Swift method signatures remain intact. `RestrictionFailure.monitoringInterrupted` is an additive case that requires updating exhaustive switches. A paused completed session can appear in `activeSession` with an unconfigured restriction and disabled policy; use the dashboard's policy and monitoring fields to decide whether credit activation is possible. Extended `ScreenTimeServiceError` and `ScreenTimePersistenceError` distinguish unsafe scope, unsupported OS, operation overlap, monitoring/shield failures, and shared-state recovery faults.

### Phase 2A adapter handoff

The integrated frontend implements `ScreenTimeServicing` with the main-actor `NativeScreenTimeService` adapter under `Earnly/Integration`. Views and navigation continue to use their presentation types. The adapter maps values and hosts the system picker. The engine owns credit validation, monitoring, shielding and recovery.

| Phase 2A method or field | Native mapping |
| --- | --- |
| `snapshot()`, `reconcile()` | Map `await engine.dashboard()`. For reconciliation, run `try await engine.appDidBecomeActive()` first. Refresh the snapshot after a mutating command fails because its credit or cleanup intent may already be persisted. |
| `requestAuthorization()` | Call `try await engine.requestAuthorization()` and map the refreshed dashboard. |
| `makeSelectionPicker`, `makeSelectionLabels` | Keep the editable `FamilyActivitySelection` in the adapter. Use a temporary opaque UUID for a confirmed draft and verify it on `applySelection`. Map saved counts and IDs from the dashboard. Render supported labels from Apple tokens inside the adapter. Discard cancelled drafts. |
| `applySelection`, `updateAllowance` | Call `engine.configure(policy:selection:)` with the confirmed draft or `engine.pickerSelection()` for a settings change. Validate the allowance with `InitialAllowance(rawValue:)` and carry forward the saved practice and reward values. |
| `disableRestrictions`, `retryPendingOperation` | Call `engine.disable()` and `engine.retry()`. Surface cleanup pending and interrupted monitoring separately so the user can either retry cleanup or explicitly reconfigure. |
| `startPractice`, `submitAnswer`, `grantReward` | Use `engine.system` for session operations and `engine.finishPractice(sessionID:)` for rewards. Map each returned session's questions, attempts, and completion. |
| `cycleID`, `pendingReward`, `releasedRewardMinutes` | Read `await engine.system.currentCycle()` and match its reward session ID to the ledger. Use `activatedAt` for release, and indicate a release failure only when `NativeDashboard.rewardReleasePending` is true and the restriction reports a shield failure. |
| `rewardHistory`, `thresholdEvidenceMinutes`, `remainingMinutes` | Combine ledger credits with their persisted sessions for accuracy and totals. Map the threshold lower bound separately, and keep remaining minutes nil. |

When mirroring `.available`, require `NativeMonitoringStatus.registered` before showing an active allowance. Add the monitoring interruption case to the frontend mirror and map shared persistence faults and unsafe native selection explicitly. The factory selects native Screen Time for a configured iPhone on a supported OS. The `Earnly Demo` Debug scheme enables the deterministic adapter, and Release ignores its launch arguments. The native adapter also persists exam preferences and can save the preferred initial allowance before any activity selection is registered.
