# Xcode integration

The canonical package is the repository-root `Package.swift`. Both the package product and Swift module are named `EarnlySystems`. The package owns the source under `Earnly/{Core,Data,Domain,Infrastructure,Services}` and the systems test directories. Keep one copy of those sources. The production host imports the product and retains the frontend agent's existing app entry point and feature sources.

## XcodeGen host and extension targets

Merge the following configuration into the existing frontend `project.yml`. Keep the existing frontend and test settings. Use the real registered host identifier in `EARNLY_HOST_BUNDLE_ID`. Set `EARNLY_APP_GROUP_ID` to a real registered App Group in the team's local signing configuration. The committed target fragment intentionally leaves these project-wide values to the host.

```yaml
include:
  - EarnlyExtensions/targets.yml
packages:
  EarnlySystems:
    path: .
targets:
  Earnly:
    sources:
      - path: Earnly
        excludes: [Core, Data, Domain, Infrastructure, Services]
    dependencies:
      - package: EarnlySystems
        product: EarnlySystems
      - target: EarnlyDeviceActivityMonitor
        embed: true
      - target: EarnlyShieldConfiguration
        embed: true
      - target: EarnlyShieldAction
        embed: true
    settings:
      base:
        CODE_SIGN_ENTITLEMENTS: EarnlyExtensions/FamilyControlsAppGroup.entitlements
        INFOPLIST_KEY_EarnlyAppGroupIdentifier: $(EARNLY_APP_GROUP_ID)
  EarnlyTests:
    sources:
      - path: EarnlyTests
        excludes: [Domain, Infrastructure, Services]
```

Set the host's `PRODUCT_BUNDLE_IDENTIFIER` and `EARNLY_HOST_BUNDLE_ID` to the same real identifier. Place `EARNLY_HOST_BUNDLE_ID` and `EARNLY_APP_GROUP_ID` at project scope so the fragment's bundle and Info.plist settings resolve for every extension. For a generated host Info.plist, confirm that the final product includes `EarnlyAppGroupIdentifier`. If Xcode drops that custom generated key, use an explicit host Info.plist entry or inject the configuration through the host's composition root. Regenerate with `xcodegen generate`. The host scheme embeds all three products under `PlugIns`. The standalone `EarnlySystems` scheme runs systems tests.

| Target | Extension point | Principal class | Dependencies |
| --- | --- | --- | --- |
| EarnlyDeviceActivityMonitor | `com.apple.deviceactivity.monitor-extension` | `$(PRODUCT_MODULE_NAME).EarnlyActivityMonitor` | EarnlySystems, DeviceActivity, FamilyControls, ManagedSettings |
| EarnlyShieldConfiguration | `com.apple.ManagedSettingsUI.shield-configuration-service` | `$(PRODUCT_MODULE_NAME).EarnlyShieldConfiguration` | ManagedSettingsUI, ManagedSettings, UIKit |
| EarnlyShieldAction | `com.apple.ManagedSettings.shield-action-service` | `$(PRODUCT_MODULE_NAME).EarnlyShieldAction` | ManagedSettings |

The extension Info.plists are included. Each extension uses `APPLICATION_EXTENSION_API_ONLY=YES`, iOS 17.0 and `SKIP_INSTALL=YES`. Match the host's marketing version and build number and sign extensions with the same team as the app. A Device Activity Report target is optional and has no current consumer.

## Signing and metadata

1. Register the real host and the three real extension bundle IDs. The fragment uses suffixes `.DeviceActivityMonitor`, `.ShieldConfiguration`, and `.ShieldAction`. Change a suffix if it conflicts with registered project IDs, and ensure the corresponding provisioning profile matches.
2. Configure Family Controls on the app and every extension. Host and Device Activity Monitor also share the registered App Group. Use the same group value in the host and monitor Info configuration and in both signed entitlements. Shield Configuration and Shield Action use static policy and require only Family Controls.
3. Use development provisioning for the signed physical-device trial. For distribution, the Apple Developer Account Holder must request the Family Controls entitlement separately for the app and every Screen Time extension, then refresh profiles and verify the resulting signatures. Inspect the archived host and each embedded extension with `codesign -d --entitlements - <bundle-path>`. [Apple Family Controls configuration](https://developer.apple.com/documentation/xcode/configuring-family-controls) · [Distribution entitlement requests](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) · [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
4. Supply the original Earnly mark as an image set named `EarnlyShieldMark` in the Shield Configuration target when the branding owner provides the appropriate export. The current shield uses the system layout with no icon if this asset is absent. For the signed direct-open experiment only, set the Boolean `EarnlyEnableDirectShieldOpen` in **both** shield Info.plists. Keep the values matched so the action and label agree. Leave it off in distribution builds until verified on individual authorization.

Development simulation still runs from the Swift package and needs no capabilities. Native construction fails with `ScreenTimePersistenceError.containerUnavailable` when the group is inaccessible.
