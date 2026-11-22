# Earnly Phase 2B systems

The host imports the existing Swift 6 `EarnlySystems` package. Device Activity Monitor uses the same extension-safe product and a narrow synchronous bridge. The shield presentation and action targets use Apple frameworks directly. The iOS deployment target remains 17.0. Native allowance configuration requires iOS 17.4 for the explicit fresh-activity setting.

## Implementation

| Area | Owner and behavior |
| --- | --- |
| Practice and accounting | `EarnlySystem` remains the single writer of the private learning file. A valid completion earns at most one credit. Activation follows verified release or recovery of a recorded release confirmation. |
| Host platform orchestration | `AppleScreenTimeEngine` and `ScreenTimeCoordinator` refresh authoritative authorization, drive durable operations, handle configuration and disablement, and expose a checked dashboard. |
| Selection | The host passes the confirmed system picker selection. The App Group stores only the Codable opaque selection and aggregate counts. Empty selections, categories and unverifiable self-exclusion are rejected. |
| Monitoring | `AppleScreenTimeBackend` registers a single named, nonrepeating window per UUID and uses a threshold with `includesPastActivity: false`. The callback names include the UUID and must both match. |
| Extension coordination | `ScreenTimeJournal` shares a versioned snapshot protected by a permanent advisory file lock and atomic replacement. Monitor callbacks commit their receipt before writing to Earnly's named settings store. The host can recover an interrupted shield write. |
| User control | Disablement fences old callbacks, attempts to stop owned monitors and clear the named store, then persists disabled host state. The host can resume an unfinished cleanup. Completed unactivated credits survive disablement. |
| Shield | The extension uses the approved palette and copy within Apple's system layout. Manual return is the default. Direct opening is gated by both OS version and matching opt-in configuration in the two shield targets. |

## Reward and crash recovery

1. Commit the completed session and credit in the host's existing file. The credit and its next generation are stored together.
2. Publish that generation and its exact window in the App Group, retire other Earnly registrations, then verify the matching framework schedule and event. Reuse an already matching registration on retry. When registration fails, the earlier shield remains applied where available.
3. Commit release intent to the shared journal before clearing the named store. After verifying the store was cleared, commit release confirmation. A threshold after confirmation can be reconciled if the host has yet to record activation. A threshold between intent and confirmation leaves the shield applied and exposes interruption with the credit still pending.
4. On threshold, the extension fences the generation, persists a single receipt and attempts shielding. The host imports the receipt, confirms its own shield stage, and acknowledges it. A threshold before release intent requires retry with a fresh generation and the same credit.
5. A missing registration or expired window surfaces an interruption. The system attempts to shield. Explicit cleanup and reconfiguration are required because residual usage is unknown. An expired generation itself grants no credit. Clear only the dedicated store and stop only activities under the Earnly prefix.

An atomic file replacement does not itself prevent lost updates. Host and extension lock a separate private inode for every journal read and mutation. Managed Settings shield changes share that lock. Device Activity calls run outside it because registration and stopping may deliver callbacks. Lock waits are bounded. A killed writer releases the lock, and the next process sees the old or new complete snapshot. Incompatible or corrupt bytes stay in place. Cleanup can stop and clear owned effects even when recovery of those bytes requires manual intervention.

## Verification and release gates

Xcode 26.6 built the package and a disposable integration checkout of the existing Earnly host for a generic iOS device with signing disabled. The resulting app contained the Device Activity Monitor, Shield Configuration, and Shield Action products under `PlugIns`. All 27 systems tests passed on macOS and in the iOS 26.5 iPhone 17 Pro simulator. These tests run the real state machine and journal using platform doubles. Native authorization, foreground usage, extension invocation, shield behavior and repeated 10-minute cycles remain unverified on physical hardware.

The Phase 1 scenarios and Phase 2 regression tests exercise the real journal and coordinator with deterministic platform doubles. They cover repeated thresholds, fresh generations, restart, corrupt files, authorization loss, empty selection, policy changes, interval interruption, disablement faults, and registration and release retries. The [integration guide](xcode-integration.md) documents the host and extension target layout. The [device test plan](device-test-plan.md) records the remaining signed-device acceptance work. [Screen Time feasibility](screentime-feasibility.md) describes usage semantics and platform risks.
