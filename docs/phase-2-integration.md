# Earnly Phase 2 integration

Open `Earnly.xcodeproj` at the root of the `integration/phase-2` checkout. The branch contains frontend commit `0235f33` and systems commit `fbba4d4`, with an ordinary merge commit and no merge conflicts. The design system, app assets and navigation implementation are unchanged from the frontend branch.

## Integrated behavior

The main-actor native adapter connects the frontend service contract to `EarnlySystems`. It presents Apple's token picker, preserves the earlier selection on cancellation, reconciles foreground activation, saves exam preferences and the initial allowance, and reads practice and rewards from the same local systems ledger. The UI distinguishes a verified monitoring registration, a pending shield release, interrupted monitoring, and incomplete cleanup. Exact remaining Screen Time stays unavailable. The `Earnly Demo` scheme enables the existing debug simulation for simulator use.

The host and monitor extension link the same local systems package. The generated app embeds Device Activity Monitor, Shield Configuration and Shield Action. Host and monitor share the configured App Group. The three extensions and host declare Family Controls for device builds. The existing `project.yml` and the included extension target specification preserve the setup on regeneration.

The two original Xcode projects had identical shared schemes and workspace definitions. The canonical project already included three presentation test files missing from `Earnly 2.xcodeproj`. The duplicate had no unique tracked build settings, source registrations or assets. It was removed from the integration branch after the canonical build and tests passed.

## Verification

- Xcode 26.6 compiled the unsigned Release host and all three extensions for a generic iOS device. Inspected each embedded extension's bundle identifier, extension point and principal class. Confirmed the Release binary excludes the fixture launch flags.
- The canonical `Earnly` scheme passed 66 tests on the iPhone 17 Pro simulator with iOS 26.5. These comprise 33 presentation tests, 28 systems tests and five UI tests.
- The independent Swift package passed its 28 tests on macOS.
- XcodeGen 2.46.0 regenerated a byte-identical project file after duplicate removal. All Info.plist and entitlement files passed `plutil` lint.

```sh
xcodegen generate
swift test
xcodebuild -project Earnly.xcodeproj -scheme Earnly \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Earnly.xcodeproj -scheme Earnly -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Remaining device acceptance

Use the real Team, App Group and provisioning configuration in the [Xcode guide](xcode-integration.md), then follow the [physical-device test plan](device-test-plan.md). Authorization, picker selection, native callback delivery, shielding, and repeated ten-minute allowances remain unverified on physical hardware. The Account Holder must request Family Controls distribution approval for the host and each extension.

Native monitoring requires iOS 17.4 or later. Broad categories are rejected. An individual app selection requires a verifiable Earnly self-exclusion token. When the framework cannot provide it, a separately selected individual website can be tested. The default shield action closes the selected activity and asks the student to return to Earnly manually. The instructional catalog remains the Phase 1 demo bank, with a full default SAT set and smaller samples for other exams. [Screen Time feasibility details](screentime-feasibility.md)
