#!/bin/sh
# Resolve the signing team only in Xcode Cloud's temporary checkout.
set -eu

if [ "${CI_XCODE_CLOUD:-}" != "TRUE" ]; then
    echo "Not running in Xcode Cloud; leaving signing settings unchanged."
    exit 0
fi

python3 - <<'PY'
import os
import re
from pathlib import Path

team = os.environ.get("CI_TEAM_ID", "")
if not re.fullmatch(r"[A-Z0-9]{10}", team):
    raise SystemExit("A valid Xcode Cloud CI_TEAM_ID is required.")
root = Path(os.environ["CI_PRIMARY_REPOSITORY_PATH"])
project = root / "Yattee.xcodeproj/project.pbxproj"
text = project.read_text()
placeholder = "$(YATTEE_PROFILES_TEAM)"
if placeholder not in text:
    raise SystemExit("Expected the fork's signing-team placeholder; check project settings.")
project.write_text(text.replace(placeholder, team))
print("Configured signing team in the temporary Xcode Cloud checkout.")
PY
