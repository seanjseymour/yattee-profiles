#!/usr/bin/env python3
"""Configure a disposable checkout for manual, internal-only tvOS distribution."""
import datetime
import os
from pathlib import Path
import plistlib
import re

APP_ID = "com.seanjseymour.yatteeprofiles"
TOP_ID = APP_ID + ".TopShelf"
GROUP = "group." + APP_ID + ".shared"


def profile_uuid(profile, bundle_id, team):
    entitlements = profile["Entitlements"]
    if profile.get("TeamIdentifier") != [team]:
        raise ValueError("Provisioning profile belongs to another team.")
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    if entitlements.get("application-identifier") not in [p + "." + bundle_id for p in prefixes]:
        raise ValueError("Provisioning profile does not match the fork's bundle identifier.")
    if "tvOS" not in profile.get("Platform", []):
        raise ValueError("A tvOS provisioning profile is required.")
    if (entitlements.get("get-task-allow", True) or profile.get("ProvisionedDevices")
            or profile.get("ProvisionsAllDevices") or not entitlements.get("beta-reports-active")):
        raise ValueError("A tvOS App Store distribution profile is required.")
    if profile["ExpirationDate"] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
        raise ValueError("Provisioning profile has expired.")
    if GROUP not in entitlements.get("com.apple.security.application-groups", []):
        raise ValueError("Provisioning profile is missing the fork's app group.")
    if bundle_id == APP_ID:
        if "iCloud." + APP_ID not in entitlements.get("com.apple.developer.icloud-container-identifiers", []):
            raise ValueError("Main profile is missing the fork's iCloud container.")
        if "CloudKit" not in entitlements.get("com.apple.developer.icloud-services", []):
            raise ValueError("Main profile is missing CloudKit.")
        if entitlements.get("aps-environment") != "production":
            raise ValueError("Main profile is missing production push entitlement.")
    uuid = profile["UUID"]
    if not re.fullmatch(r"[A-Fa-f0-9-]{36}", uuid):
        raise ValueError("Invalid profile UUID.")
    return uuid


def configure_project(text, profiles):
    found = set()

    def update(match):
        block = match[0]
        if not re.search(r"\n\t{3}name = Release;", block):
            return block
        for bundle_id, uuid in profiles.items():
            if f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};" in block:
                if bundle_id in found:
                    raise ValueError("Duplicate Release target configuration.")
                found.add(bundle_id)
                if "PROVISIONING_PROFILE" in block:
                    raise ValueError("Unexpected pre-existing profile override.")
                return block.replace("CODE_SIGN_STYLE = Automatic;",
                                     'CODE_SIGN_STYLE = Manual;\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";\n'
                                     f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{uuid}";')
        return block

    result = re.sub(r"\t{2}[A-F0-9]{24} /\* [^\n]+ \*/ = \{\n\t{3}isa = XCBuildConfiguration;.*?\n\t{2}\};",
                    update, text, flags=re.DOTALL)
    if found != set(profiles):
        raise ValueError("Could not locate both Release target configurations.")
    return result


def export_options(team, profiles):
    return {"method": "app-store-connect", "destination": "upload",
            "teamID": team, "signingStyle": "manual", "signingCertificate": "Apple Distribution",
            "provisioningProfiles": profiles, "testFlightInternalTestingOnly": True,
            "manageAppVersionAndBuildNumber": False, "uploadSymbols": True,
            "iCloudContainerEnvironment": "Production"}


def main():
    team = os.environ["YATTEE_PROFILES_TEAM"]
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Set YATTEE_PROFILES_TEAM to the paid team's ID.")
    build = os.environ["BUILD_NUMBER"]
    if not re.fullmatch(r"[1-9][0-9]{0,7}", build) or int(build) < 280:
        raise ValueError("Choose an unused integer build number of at least 280.")
    temporary = Path(os.environ["RELEASE_TEMP"])
    profiles = {}
    for filename, bundle_id in (("app", APP_ID), ("topshelf", TOP_ID)):
        with (temporary / (filename + ".plist")).open("rb") as handle:
            profiles[bundle_id] = profile_uuid(plistlib.load(handle), bundle_id, team)
    project = Path("Yattee.xcodeproj/project.pbxproj")
    updated = configure_project(project.read_text(), profiles)
    project.write_text(updated)
    with (temporary / "ExportOptions.plist").open("wb") as handle:
        plistlib.dump(export_options(team, profiles), handle)
    print("Validated both tvOS distribution profiles and configured internal-only export.")


if __name__ == "__main__":
    main()
