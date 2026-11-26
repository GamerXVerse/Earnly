# Earnly TestFlight deployment

Open `earnly-integration/Earnly.xcodeproj` on `integration/phase-2`. Use the shared **Earnly** scheme. Its Archive action uses Release, which compiles the native Screen Time service and excludes the Debug simulation entry points. The **Earnly Demo** scheme is for local Debug use.

## Signing identities

The App Store Connect record **Earnly: Study to Unlock** lists `com.earnly-testing-secure.app`. The existing Apple-issued development provisioning profiles confirm the four identifiers and their App Group memberships below. The repository previously defaulted to `com.earnly.app` with an empty App Group. An ignored local xcconfig and local Xcode edits masked those values. A clean Cloud checkout used the defaults.

| Xcode target | Bundle identifier | App Group | Family Controls |
| --- | --- | --- | --- |
| Earnly | `com.earnly-testing-secure.app` | `group.com.earnly-testing-secure.app` | Required |
| EarnlyDeviceActivityMonitor | `com.earnly-testing-secure.app.DeviceActivityMonitor` | `group.com.earnly-testing-secure.app` | Required |
| EarnlyShieldConfiguration | `com.earnly-testing-secure.app.ShieldConfiguration` | `group.com.earnly-testing-secure.app` | Required |
| EarnlyShieldAction | `com.earnly-testing-secure.app.ShieldAction` | None | Required |

The host embeds all three extensions. Shield Action handles the shield buttons and has no shared-container dependency. The group appears in the device entitlement and in the runtime Info.plist of each of its three members. The bundle IDs are explicit in the Xcode project and its XcodeGen sources to let Xcode Cloud discover the right product. Debug and Release use the same registered IDs and automatic signing. For local development, the ignored `Config/Signing.local.xcconfig` can supply `DEVELOPMENT_TEAM`; Xcode Cloud uses the team associated with its product. The project leaves the Release app's signing identity to automatic signing. [Apple’s Xcode Cloud product setup](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)

## Apple Developer Portal

1. Sign in as the **Account Holder**. In **Certificates, Identifiers & Profiles → Identifiers**, verify that all four App IDs in the table are registered on the team owning the App Store Connect record. Confirm `group.com.earnly-testing-secure.app` is registered and assigned to all three listed members. [Configure App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
2. Request **Family Controls (Distribution)** separately for each of the four IDs. Describe why Earnly uses Screen Time, how users authorize and select apps, and what the monitor and shield extensions do. If requests are already pending, check their status on the existing IDs. [Family Controls entitlement request](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
3. Wait for Apple to assign the distribution capability to every ID. Confirm it is enabled and supports the App Store provisioning type. With automatic signing, use a fresh Cloud build to generate or refresh distribution profiles. If using manually managed profiles, regenerate the App Store profile for each affected target after approval. The existing development profiles cover local device builds. App Store distribution profiles require Apple's separate approval.

## Xcode Cloud

1. In App Store Connect, open the [verified Earnly record](https://appstoreconnect.apple.com/apps/6839490341/distribution/info), then manage its Xcode Cloud workflows. Confirm the source repository is `GamerXVerse/Earnly`. If an old workflow is tied to `com.earnly.app`, use the matching product and configure the workflow there.
2. Target `integration/phase-2` for this beta. Use the canonical `Earnly.xcodeproj`, the shared **Earnly** scheme, and an **iOS Archive** action. Choose **TestFlight and App Store** for external testing. A build marked **TestFlight Internal Only** is ineligible for an external testing group. Use a currently supported Xcode and macOS environment. Keep automatic tester distribution disabled until you intend to release a build. [Apple’s distribution workflow guide](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution)
3. Remove stale bundle ID, signing-team, provisioning-profile, or debug overrides from the workflow. The repository’s archive preflight compares the resolved Release host ID with Xcode Cloud’s `CI_BUNDLE_ID` and checks that the Release build settings exclude `DEBUG`. The post-archive check inspects the compiled app and its three embedded extensions for required bundle metadata, including display names, matching versions, and extension declarations. Let Cloud assign a build number and verify it is higher than any previously uploaded build.
4. Once all four distribution capabilities are approved, start a fresh build from the updated branch. In **Builds**, confirm that the archive and App Store export both succeed before using the build in TestFlight. If export fails, open the archive action’s distribution logs and match any target-specific error to its identifier in the table.

## Generate the public TestFlight link

1. In the Earnly record, open **TestFlight** and wait for the build to finish processing. Complete any export compliance questions and enter **Test Information**, including a feedback contact, review notes and instructions for testing the Screen Time flow.
2. Under **External Testing**, create a group and add the processed build. Submit it for TestFlight App Review when prompted. Install the processed build on a physical iPhone and verify authorization, selection, shielding, practice completion and reward unlock before sharing it broadly.
3. After approval, open the external group, choose **Create Public Link**, choose any tester criteria or participant limit, and copy the link. [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

## Verification

Local unsigned and development-signed Release archives succeeded. All three extensions were present in the archived app. The app and extension signatures contained the expected bundle IDs, Family Controls entitlement, and App Group memberships. All 30 Swift package tests passed. The Cloud preflight passed locally with the registered ID and rejected the old ID.

Xcode Cloud Build 5 reportedly exported for App Store distribution, then Transporter rejected the IPA with error 90360 because the three extensions lacked display names. The display names are now in the extension source plists. Use a fresh Cloud archive to verify Transporter acceptance. A physical-device run of the TestFlight build remains unverified.
