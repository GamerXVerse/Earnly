# Signed iPhone Screen Time acceptance

No physical iPhone results were collected for Phase 2B. Repeated 10-minute cycles remain unverified. Record each run's device model, exact iOS build, signed host and extension build, authorization mode, selection type, approximate foreground-use time, threshold callback time, observed shield behavior, and pass/fail/blocked status. Use system UI or manual timing for test observations and keep token and browsing details out of logs.

## Prerequisites

Use the [Xcode integration guide](xcode-integration.md) to embed and sign the host and all three extensions with the team's real identifiers and App Group. Wire the host scene activation and practice actions using the [frontend contract](integration-contract.md). Install the development build, leave direct shield opening off for the first run, and connect Xcode to the device logs. Use standard SAT settings with 10 required questions, a 10-minute initial allowance and a 10-minute reward. An iOS 17.4+ device is required for native setup. Use a current iPhone on iOS 26.5 or later for the optional direct-open trial.

## Primary acceptance sequence

1. Open Earnly and request individual Family Controls authorization. Verify the system prompt and that the host reports approval after foreground reconciliation.
2. Open the system picker and choose **one entertainment app**. Confirm the selection and check that the host reports a matching registration with a 10-minute threshold. Expand the category and select only the app row. Leave Earnly unchecked. If saving fails, record the exact error and the device OS/build. Run an explicit Safari web-domain trial separately.
3. Use the selected entertainment activity in bursts totaling roughly 10 minutes of foreground usage. Spend part of the interval in unselected apps or with the device locked. Verify the shield appears when the selected activity crosses its threshold. Record overshoot and callback delay. Repeat with the host terminated before the callback. Check that Earnly itself remains accessible.
4. Tap **Close**, return through the Home Screen, and open Earnly. Confirm the dashboard reconciles the shield and offers practice. Start the SAT session. Submit one answer per question, including some incorrect answers. Verify the explanation and accuracy, then finish the session. Verify one 10-minute credit in the ledger and a fresh monitoring generation. Verify the selected app opens once Earnly's shield is released.
5. Reopen the same entertainment app. Accumulate about 10 **new** minutes of selected foreground usage. Verify the shield returns, the new cycle records threshold evidence, and repeat completion requests still show one credit for the original session. Repeat the practice/reward sequence at least twice more without reinstalling. If a threshold fires immediately after re-registration or the second block never arrives, record a failure and preserve the generation and timing evidence.

## Additional cases

| Trial | Expected | Actual / device OS / status |
| --- | --- | --- |
| Initial 15 minutes; reward 10 minutes | First shield follows the configured 15-minute accumulation, second follows a fresh 10-minute allowance. | — / — / Unverified |
| First and second 10-minute allowances, individual mode | Thresholds track new usage by generation while the unselected and locked time does not accumulate. | — / — / Unverified |
| Kill host after the last answer, after credit commit, after registering, and after setting release intent or clearing the shield | Foreground recovery executes only the pending effects and preserves one credit. Use debug breakpoints around the durable steps. | — / — / Unverified |
| Extension interruption after receipt commit and before shield application | The host replays the receipt and repairs the shield. Duplicate callbacks converge on the same receipt. | — / — / Unverified |
| Cancellation, empty selection, categories and self-selection | A cancelled draft preserves the old scope. Empty and broad categories fail. A known Earnly token is removed before configuration. If the system ever shields Earnly, its own shield configuration should allow the student to close and reopen Earnly. | — / — / Unverified |
| Replace selection and then change policy | Old-generation callbacks do not apply the old shield. The replacement scope and threshold take effect. | — / — / Unverified |
| Disable while active, shielded, and reward pending | Earnly registrations and the named shield clear. A completed unactivated credit persists through retries. Unrelated restrictions survive. | — / — / Unverified |
| Revoke in Settings, then reopen Earnly | Monitoring and its own shield are reconciled, the old selection is invalidated, and a fresh picker is required. | — / — / Unverified |
| Calendar end, timezone change, DST, and reboot before/after first unlock | Stale or expired generations do not reset usage or earn credits. The host exposes interruption and supports explicit cleanup. | — / — / Unverified |
| iOS 17.0–17.3 and iOS 17.4+ | Earlier hosts can show simulation or the compatibility state. On 17.4+, test actual fresh counting, callback ordering and shield results. | — / — / Unverified |
| iOS 26.5+ with direct-open flag in both shield targets | Open Earnly launches this app under individual authorization. Test app and web shields. Flag off and earlier OS use Close and manual return. | — / — / Unverified |

Keep production defaults throughout initial acceptance. A separately signed QA build may use a shorter cumulative threshold or a smaller practice count to investigate a specific failure. Keep any debug changes out of Release, and keep the monitoring window at or above Apple's 15-minute minimum. Confirm all release gates again at the real 10- and 15-minute thresholds.
