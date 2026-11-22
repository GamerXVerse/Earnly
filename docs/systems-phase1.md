# Earnly systems foundation

The GitHub repository was empty when work began. Phase 1B adds a local Xcode-compatible Swift package with an `EarnlySystems` scheme and an `EarnlySystemsTests` target. The package declares an iOS 17 deployment minimum and uses Swift 6 concurrency checking. It can also run logical tests on macOS 14 or later. Integration with an iOS application target is covered in the [frontend contract](integration-contract.md).

## Source layout

| Directory | Responsibility |
| --- | --- |
| `Earnly/Domain` | Exam, profile, policy, question, practice, reward and restriction models. The lifecycle reducer validates explicit events. |
| `Earnly/Services` | Contracts for authorization, selections, shielding, usage monitoring, questions, practice, rewards, profile persistence and extension threshold receipts. |
| `Earnly/Data` | Versioned state, cross-record validation and original sample questions. |
| `Earnly/Infrastructure` | Atomic local storage, simulated platform adapter and optional Apple individual authorization adapter. |
| `Earnly/Core` | `EarnlySystem` actor owns state transitions and persistence. Its outputs include pending device operations and dashboard snapshots. |
| `EarnlyTests` | Swift Testing suites for domain rules, lifecycle and persistence. |

## Invariants

| Model | Invariant |
| --- | --- |
| `ExamType`, `StudyProfile` | AP identity includes a stable subject code. A profile may select multiple examinations and supply a difficulty preference. An empty profile is valid. The demo catalog uses SAT for that case. |
| `ScreenTimePolicy` | Initial allowance is 10 or 15 minutes. Question count and reward are independent positive integers. Enabled is independent of authorization and configuration. Decoding enforces the same constraints as construction. |
| `EarnlyQuestion`, `AnswerOption` | Questions have stable IDs and unique option IDs within a question. The answer key identifies one option. The session checks the entire question set before publishing it. |
| `PracticeSession`, `QuestionAttempt` | The session freezes its questions and reward terms. A valid submission is immutable and replayable. Completion requires one answer per question, and timestamps are ordered. Accuracy is recorded separately. |
| `RewardTransaction`, `RewardLedger` | Session ID is the idempotency key. A credit corresponds to a valid completed session and has the frozen number of minutes. Shield release sets the activation timestamp. A later matching threshold provides a consumption lower bound. |
| `ActivitySelection`, `UsageCycle` | The domain sees a local opaque key and aggregate counts. A selection must contain at least one supported item. A cycle ID identifies a monitoring generation, and threshold callbacks carry that ID. |
| `RestrictionState`, `DashboardSnapshot` | Snapshot state comes from validated transitions. Authorization, monitoring or shielding failures, and setup can suppress availability. Metric values carry provenance. Remaining time is unavailable in Phase 1. |

## Lifecycle and recovery

An approved user with a selection moves from unconfigured through registration and confirmed shield release to available. A matching threshold records evidence and schedules shield application. Confirmation makes the session eligible to start. The final valid submission creates reward-pending state. Granting a reward atomically inserts one ledger credit and the next monitoring intent. A valid completed session can be credited even when authorization is suspended. The adapter installs monitoring before it releases the shield. Confirmed release activates the credit and makes the new cycle available. A repeated threshold, a repeated answer with the same option, and a repeated grant converge on the existing state. A competing answer for an already attempted question fails explicitly.

Callers retry failed effects in their original generation. A threshold during installation or release exposes `thresholdBeforeRelease`. Retrying that case allocates a fresh generation after platform cleanup. The host must recheck authorization and platform state after a restart. A permission loss invalidates the prior selection and suspends the lifecycle. A newly confirmed selection can resume interrupted practice or an in-flight reward after reapplying shielding where needed. A previously activated, interrupted allowance has unknown consumption and requires explicit reconfiguration. Reset invalidates old generations and retains historical sessions and credits. Reset can abandon unfinished practice. Reset is blocked while a completed session is awaiting credit or a granted credit is awaiting activation.

## Persistence

Use one `EarnlySystem` instance per file, with the lifetime of the host app. The versioned JSON file is in the host's Application Support directory. Every mutation persists the whole snapshot with atomic replacement before publishing it to the actor. iOS writes request file protection until first user authentication. A missing file is first launch. An unreadable file, unsupported version, parse error, or inconsistent record set stops loading and preserves the bytes. Recovery can reopen after restoring a known-good snapshot. Compare restored ledger and cycle state with any existing platform registration before resuming. A recovery reset requires first reconciling or clearing the Earnly-owned platform state. Loading a broken file never creates a reward.

Phase 1 keeps preferences in the same snapshot to avoid coordinating policy, session and credit writes across stores. UserDefaults suits independent presentation preferences once such preferences exist. SwiftData is an option on iOS 17 for queryable learning history as the catalog and attempt volume grow. A migration must preserve session IDs and validated transactions, and keep registration intent and reward credit atomic or join them with a durable recovery protocol. The JSON snapshot is intended for small local histories. The App Group boundary and interprocess transaction design are covered in the [Screen Time report](screentime-feasibility.md).

## Verification

From the systems worktree, open `Package.swift` in Xcode to use the `EarnlySystems` scheme, or run these commands.

```sh
swift test
xcodebuild -scheme EarnlySystems -showdestinations
xcodebuild -scheme EarnlySystems \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Xcode 26.6 and the iOS 26.5 SDK built the package for the iOS 17 deployment target. All 15 logical tests passed on macOS and on an iPhone 17 Pro simulator running iOS 26.5. The unsigned generic iOS device build also succeeded. The simulator compiles the optional Apple authorization adapter while the tests exercise the simulated platform. Physical-device authorization, shielding, callback delivery, and distribution signing remain Phase 2 acceptance work.
