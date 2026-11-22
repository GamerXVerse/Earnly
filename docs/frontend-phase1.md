# Earnly Phase 1A: Frontend

Swift / SwiftUI, iOS 17+, Observation (`@Observable`). Branch `agent/frontend`.
The project is generated from `project.yml` with XcodeGen (`xcodegen generate`); `Earnly.xcodeproj` is committed.

## Architecture

```
Earnly/
  EarnlyApp.swift, ContentView.swift   shell: onboarding until complete, then tabs
  DesignSystem/  Tokens, Components, Brand, Motion
  Navigation/    AppRouter, MainTabView
  Presentation/  Onboarding, Today, Practice, Progress, Settings, PreviewSupport
```

All temporary models live in `Presentation/PreviewSupport/` and are prefixed `Preview*` so they cannot collide with production domain models. UI reads only the properties and calls only the callbacks listed below.

## Design system

- Tokens: `EarnlyColor` (brand #6155F5, success #A5F2C3, ink #141422, canvas #F6F7FB, surface #FFFFFF, plus dark-mode and semantic values), `EarnlySpacing` (4–40), `EarnlyFont` (text styles, Dynamic Type), `EarnlyGeometry` (radii 8–12, 44 pt targets).
- Components: `EarnlyButton` / `.earnlyPrimary|Secondary|Text`, `EarnlyProgressBar`, `EarnlyStepIndicator`, `EarnlySelectionRow`, `EarnlySectionHeader`, `EarnlyDivider`, `EarnlyStatusMessage`, `EarnlyPreviewTag`.
- Brand: `EarnlyLogo` (vector Path geometry: unlocked padlock with integrated checkmark), `EarnlyWordmark` (`earnly.`), `EarnlyLockup`. App icon is a 1024 px PNG in `Assets.xcassets/AppIcon.appiconset`.
- Motion: durations 180–320 ms; `earnlyAnimation`, `earnlyParallax` (max 6–16 pt, intro hero), haptics. All motion is skipped under Reduce Motion.

## Navigation

`AppRouter` owns `selectedTab`, `settingsPath`, and `practiceLaunch` (full-screen practice cover). Each tab has its own `NavigationStack`. `router.startPractice(startingAt:)` is the entry point a restriction shield can route into. `router.open(.permissions)` etc. deep-links into Settings.

## Required data (Phase 2 supplies)

**Dashboard** (`PreviewRestrictionState`): `remainingSeconds?` (nil = unknown, shows `--:--`), `allowanceSeconds`, status title/detail/tone, primary action (`finishSetup | startPractice | resumePractice | reviewPermission`), `questionsToday?`, `minutesEarnedToday?`, `sessionProgress?`. The UI never assumes second-by-second usage data; the hero value is labeled preview/sample.

**Question/session** (`PreviewQuestion`, `PreviewPracticeSession`): stem, choices, correct index, explanation, section label; session index/total, selected choice, phase (`answering | submitted | completed`), correct count, reward minutes.

**Authorization** (`PreviewAuthorizationState`): `notDetermined`, `denied`, `unavailable`, plus `simulatedGranted` (development only, always labeled).

**Reward/restriction**: reward rule (10 questions = 10 minutes), allowance (10/15 min), dashboard states: first launch incomplete, available, exhausted, practice required, practice in progress, earned, authorization unavailable.

## Callbacks (integration seams, in `PreviewAppModel`)

- `requestAuthorization(simulating:)` → forward to the Screen Time authorization service.
- `completeOnboarding()` → persist profile, enter app.
- `finishPractice()` → report completed session, credit reward.
- `restartOnboarding()` → development reset.
- Router: `startPractice`, `dismissPractice`, `open(_:)`.

## Development-only behavior

- Settings → Development: Today state picker, demo/empty Progress toggle, restart onboarding.
- Permissions: simulated grant/decline; the UI states no real access exists.
- Nothing is persisted. Practice reward does not touch a real allowance.
- Launch arguments for tests/screenshots: `-earnly-skip-onboarding`, `-earnly-state <rawValue>`, `-earnly-empty-progress`.
- Sample questions are original; the Progress charts use demo data.

## Phase 2 requirements

1. Replace `PreviewAppModel` stored values with systems-layer services; keep view signatures.
2. Wire FamilyControls authorization into `requestAuthorization`, and the app picker into Settings → Screen time.
3. Supply real question delivery and session management behind `PreviewPracticeSession`'s interface.
4. Make allowance/reward configurable and persisted; remove Development tools.
5. Entitlements, signing, and extension targets are not configured here.
6. Add AP exam content and the matching subject list.

## Verification (Xcode 26.6, iPhone 17 Pro simulator)

Build succeeds; 7 unit tests and 2 UI tests pass. Screenshots were reviewed for intro, Today (available, practice required, in progress, dark mode). Practice, Progress, Settings and the remaining onboarding steps were not screenshot-reviewed; the practice flow is covered by a UI test. Reduce Motion, VoiceOver, and the smallest-device/large-text layouts were not manually tested.
