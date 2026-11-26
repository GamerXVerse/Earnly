#!/bin/sh
set -eu

[ "${CI_XCODEBUILD_ACTION:-}" = archive ] || exit 0

repo_dir="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
settings="$(mktemp)"
trap 'rm -f "$settings"' EXIT

xcodebuild -showBuildSettings -json \
    -project "$repo_dir/Earnly.xcodeproj" -scheme Earnly \
    -configuration Release -destination 'generic/platform=iOS' > "$settings"

/usr/bin/python3 - "$settings" <<'PYTHON'
import json
import os
import sys

with open(sys.argv[1]) as file:
    settings = next(
        entry["buildSettings"] for entry in json.load(file) if entry.get("target") == "Earnly"
    )

bundle_id = settings["PRODUCT_BUNDLE_IDENTIFIER"]
cloud_bundle_id = os.environ.get("CI_BUNDLE_ID", "")
if cloud_bundle_id != bundle_id:
    sys.exit(
        f"Earnly archive bundle ID is {bundle_id}, but the Xcode Cloud product uses "
        f"{cloud_bundle_id or '<missing>'}. Select the matching Earnly App Store Connect product."
    )
if "DEBUG" in settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "").split():
    sys.exit("Earnly's Release archive must run without DEBUG.")
print(f"Earnly Release matches the Xcode Cloud product ({bundle_id}).")
PYTHON
