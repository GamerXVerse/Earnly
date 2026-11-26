#!/bin/sh
set -eu

[ "${CI_XCODEBUILD_ACTION:-}" = archive ] || exit 0
[ "${CI_XCODEBUILD_EXIT_CODE:-0}" = 0 ] || exit 0
: "${CI_ARCHIVE_PATH:?Successful archive action did not provide CI_ARCHIVE_PATH}"

exec /usr/bin/python3 - "$CI_ARCHIVE_PATH" <<'PYTHON'
import plistlib
import sys
from pathlib import Path


def read_bundle(bundle, display_name):
    with (bundle / "Info.plist").open("rb") as file:
        info = plistlib.load(file)

    for key in (
        "CFBundleDisplayName",
        "CFBundleIdentifier",
        "CFBundleName",
        "CFBundleExecutable",
        "CFBundleVersion",
        "CFBundleShortVersionString",
    ):
        value = info.get(key)
        if not isinstance(value, str) or not value.strip() or "$(" in value or "${" in value:
            raise ValueError(f"{bundle.name}: {key} is missing, blank, or unresolved")

    if info["CFBundleDisplayName"] != display_name:
        raise ValueError(f"{bundle.name}: CFBundleDisplayName must be {display_name!r}")
    if not (bundle / info["CFBundleExecutable"]).is_file():
        raise ValueError(f"{bundle.name}: CFBundleExecutable does not name an embedded binary")
    return info


app = Path(sys.argv[1]) / "Products" / "Applications" / "Earnly.app"
extensions = (
    ("DeviceActivityMonitor", "Earnly Activity Monitor",
     "com.apple.deviceactivity.monitor-extension", "EarnlyActivityMonitor"),
    ("ShieldConfiguration", "Earnly Shield Configuration",
     "com.apple.ManagedSettingsUI.shield-configuration-service", "EarnlyShieldConfiguration"),
    ("ShieldAction", "Earnly Shield Action",
     "com.apple.ManagedSettings.shield-action-service", "EarnlyShieldAction"),
)
try:
    host = read_bundle(app, "Earnly")
    for suffix, display_name, point, principal_class in extensions:
        target = f"Earnly{suffix}"
        bundle = app / "PlugIns" / f"{target}.appex"
        info = read_bundle(bundle, display_name)
        for key, expected in (
            ("CFBundleIdentifier", f"{host['CFBundleIdentifier']}.{suffix}"),
            ("CFBundleVersion", host["CFBundleVersion"]),
            ("CFBundleShortVersionString", host["CFBundleShortVersionString"]),
        ):
            if info[key] != expected:
                raise ValueError(f"{bundle.name}: {key} must be {expected!r}, got {info[key]!r}")

        declaration = info.get("NSExtension")
        if not isinstance(declaration, dict):
            raise ValueError(f"{bundle.name}: NSExtension dictionary is missing")
        for key, expected in (
            ("NSExtensionPointIdentifier", point),
            ("NSExtensionPrincipalClass", f"{target}.{principal_class}"),
        ):
            if declaration.get(key) != expected:
                raise ValueError(f"{bundle.name}: NSExtension.{key} must be {expected!r}")
except (OSError, plistlib.InvalidFileException, ValueError) as error:
    sys.exit(f"Archive metadata validation failed: {error}")

print("Archive metadata validated for Earnly and its three Screen Time extensions.")
PYTHON
