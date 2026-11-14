#!/usr/bin/env python3
"""One-shot identity isolation for the tvOS TestFlight profiles fork; no signing/network."""
import argparse
import json
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM_ID = "stream.yattee.app"
UPSTREAM_TEAM = "78Z5H3M6RJ"

def plan(root, bundle_id, scheme):
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*){2,}", bundle_id):
        raise ValueError("Use a reverse-DNS bundle identifier.")
    if bundle_id.startswith("stream.yattee"):
        raise ValueError("Use your own bundle identifier.")
    if not re.fullmatch(r"[a-z][a-z0-9-]+", scheme) or scheme == "yattee":
        raise ValueError("Use a distinct lowercase URL scheme.")
    project = root / "Yattee.xcodeproj/project.pbxproj"
    if UPSTREAM_ID not in project.read_text():
        raise ValueError("Already configured or different upstream. Apply to a fresh baseline.")
    changes = {}
    for directory in ("Yattee", "YatteeTopShelf", "YatteeShareExtension", "YatteeTests", "Yattee.xcodeproj"):
        for path in (root / directory).rglob("*"):
            if path.suffix not in (".swift", ".plist", ".entitlements", ".pbxproj"):
                continue
            old = path.read_text()
            new = old.replace(UPSTREAM_ID, bundle_id)
            # Keep parsers, generated Top Shelf URLs, and their tests in agreement.
            new = new.replace('yattee://', scheme + '://').replace('"yattee"', '"' + scheme + '"')
            new = new.replace('<string>yattee</string>', '<string>' + scheme + '</string>')
            new = new.replace('"stream.yattee.downloads"', '"' + bundle_id + '.downloads"')
            if path == project:
                new = new.replace("DEVELOPMENT_TEAM = " + UPSTREAM_TEAM, 'DEVELOPMENT_TEAM = "$(YATTEE_PROFILES_TEAM)"')
                new = new.replace("INFOPLIST_KEY_CFBundleDisplayName = Yattee;", 'INFOPLIST_KEY_CFBundleDisplayName = "Yattee Profiles";')
                new = new.replace('"Yattee Top Shelf"', '"Yattee Profiles Top Shelf"')
            if path.suffix in (".plist", ".entitlements"):
                plistlib.loads(new.encode())
            if new != old:
                changes[path] = new
    # Never enable upstream's multi-platform upload/release on the profiles fork.
    for name in ("release.yml", "update-altstore.yml"):
        workflow = root / ".github/workflows" / name
        if workflow.exists():
            changes[workflow] = None
    return changes

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--url-scheme", default="yatteeprofiles")
    p.add_argument("--apply", action="store_true")
    args = p.parse_args()
    changes = plan(ROOT, args.bundle_id, args.url_scheme)
    for path, text in changes.items():
        print(("REMOVE " if text is None else "UPDATE ") + str(path.relative_to(ROOT)))
    if args.apply:
        for path, text in changes.items():
            if text is None:
                path.unlink()
            else:
                path.write_text(text)
        (ROOT / "docs/profiles/identity.json").write_text(json.dumps({
            "bundle_id": args.bundle_id,
            "url_scheme": args.url_scheme,
            "app_group": "group." + args.bundle_id + ".shared",
            "icloud_container": "iCloud." + args.bundle_id,
            "upstream_tag": "2.0.0-beta.278",
        }, indent=2) + "\n")
    else:
        print("Dry run only. Add --apply after confirming identity registration.")
if __name__ == "__main__":
    main()
