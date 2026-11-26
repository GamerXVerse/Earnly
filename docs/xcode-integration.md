# Xcode integration

Open the repository-root `Earnly.xcodeproj`. Its checked-in source of truth is `project.yml` together with `EarnlyExtensions/targets.yml`. After changing target membership, package dependencies, or build settings, run `xcodegen generate` from the repository root and commit the updated project. XcodeGen 2.46.0 generated the integration project.

The host and Device Activity Monitor link the repository-root `EarnlySystems` package product and import its module. XcodeGen excludes the systems source folders from direct host compilation. The `Earnly` scheme runs app and systems unit tests plus UI tests; the `EarnlySystems` package can also run independently with `swift test`. Choose `Earnly Demo` to run the debug UI with deterministic data. The ordinary `Earnly` scheme selects native Screen Time on a configured iPhone, and reports unavailable when the device or build cannot provide it. Release ignores the debug fixture launch arguments.

| Target | Extension point | Principal class |
| --- | --- | --- |
| EarnlyDeviceActivityMonitor | `com.apple.deviceactivity.monitor-extension` | `$(PRODUCT_MODULE_NAME).EarnlyActivityMonitor` |
| EarnlyShieldConfiguration | `com.apple.ManagedSettingsUI.shield-configuration-service` | `$(PRODUCT_MODULE_NAME).EarnlyShieldConfiguration` |
| EarnlyShieldAction | `com.apple.ManagedSettings.shield-action-service` | `$(PRODUCT_MODULE_NAME).EarnlyShieldAction` |

The host embeds all three extensions in `PlugIns`. Each extension uses `APPLICATION_EXTENSION_API_ONLY=YES`, the iOS 17.0 deployment target, and the host's build and marketing versions. The native allowance path requires iOS 17.4 or later. Recent OS versions can opt into the direct shield-open experiment, as described below.

## Configure a signed iPhone build

1. Create `Config/Signing.local.xcconfig` in your checkout. That file is ignored. Set `DEVELOPMENT_TEAM`, `EARNLY_HOST_BUNDLE_ID`, and `EARNLY_APP_GROUP_ID` to the values from the team's actual developer account. The tracked `Config/Earnly.xcconfig` includes it optionally. The default host identifier comes from the frontend project and the shared group defaults to empty.
2. Register the host identifier and its extension identifiers, which append `.DeviceActivityMonitor`, `.ShieldConfiguration`, and `.ShieldAction`. Configure Family Controls on all four. Register the real App Group and assign it to the host, Device Activity Monitor, and Shield Configuration. The group lets Shield Configuration record recovery if Earnly itself is ever shielded. The build substitutes the same value into the device entitlements and corresponding Info.plists. Verify Xcode's selected team and profiles for all four targets before installation.
3. Select the `Earnly` scheme and a signed physical iPhone running iOS 17.4 or later. Use the [device acceptance procedure](device-test-plan.md). The Apple Developer Account Holder must request Family Controls distribution permission separately for the app and each Screen Time extension. Refresh provisioning profiles and inspect the resulting app and embedded extension signatures before distribution. [Family Controls configuration](https://developer.apple.com/documentation/xcode/configuring-family-controls) · [Distribution entitlement requests](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) · [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
4. The shield defaults to **Close** and instructions for returning manually. To test direct opening on iOS 26.5 or later, set `EarnlyEnableDirectShieldOpen` to true in both shield Info.plists in a device experiment. Keep the values matched so the label agrees with the action. The Shield Configuration target can use the original mark from an image set named `EarnlyShieldMark` once the extension-ready brand export is available.

Device entitlements are applied only for the iPhoneOS SDK. The simulator and host package tests therefore run without developer provisioning. Use `CODE_SIGNING_ALLOWED=NO` only for compilation verification on a generic iOS destination; install the signed product for the device acceptance tests.
