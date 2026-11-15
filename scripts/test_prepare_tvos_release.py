#!/usr/bin/env python3
import datetime
from pathlib import Path
import unittest

from prepare_tvos_release import APP_ID, TOP_ID, GROUP, configure_project, export_options, profile_uuid

TEAM = "ABCDE12345"
UUID = "11111111-2222-3333-4444-555555555555"


def profile(bundle=APP_ID):
    return {"TeamIdentifier": [TEAM], "ApplicationIdentifierPrefix": [TEAM],
            "UUID": UUID, "Platform": ["tvOS"],
            "ExpirationDate": datetime.datetime.now() + datetime.timedelta(days=30),
            "Entitlements": {"application-identifier": TEAM + "." + bundle,
                             "get-task-allow": False, "beta-reports-active": True,
                             "aps-environment": "production",
                             "com.apple.security.application-groups": [GROUP],
                             "com.apple.developer.icloud-services": ["CloudKit"],
                             "com.apple.developer.icloud-container-identifiers": ["iCloud." + APP_ID]}}


class ReleaseTests(unittest.TestCase):
    def test_valid_app_and_extension_profiles(self):
        for bundle in (APP_ID, TOP_ID):
            self.assertEqual(profile_uuid(profile(bundle), bundle, TEAM), UUID)

    def test_reject_wrong_identity_or_platform(self):
        for key, value in (("TeamIdentifier", ["OTHER12345"]), ("Platform", ["iOS"]),
                           ("ExpirationDate", datetime.datetime(2020, 1, 1))):
            data = profile()
            data[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                profile_uuid(data, APP_ID, TEAM)
        with self.assertRaises(ValueError):
            profile_uuid(profile(TOP_ID), APP_ID, TEAM)

    def test_reject_non_store_profiles(self):
        for key in ("ProvisionedDevices", "ProvisionsAllDevices"):
            data = profile()
            data[key] = ["device"] if key == "ProvisionedDevices" else True
            with self.subTest(key=key), self.assertRaises(ValueError):
                profile_uuid(data, APP_ID, TEAM)
        data = profile()
        data["Entitlements"]["get-task-allow"] = True
        with self.assertRaises(ValueError):
            profile_uuid(data, APP_ID, TEAM)

    def test_reject_missing_capabilities(self):
        for key in ("com.apple.security.application-groups", "com.apple.developer.icloud-services",
                    "com.apple.developer.icloud-container-identifiers", "aps-environment",
                    "beta-reports-active"):
            data = profile()
            del data["Entitlements"][key]
            with self.subTest(key=key), self.assertRaises(ValueError):
                profile_uuid(data, APP_ID, TEAM)

    def test_real_project_changes_only_two_release_configurations(self):
        root = Path(__file__).resolve().parents[1]
        old = (root / "Yattee.xcodeproj/project.pbxproj").read_text()
        profiles = {APP_ID: UUID, TOP_ID: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"}
        new = configure_project(old, profiles)
        self.assertEqual(new.count("PROVISIONING_PROFILE_SPECIFIER ="), 2)
        self.assertEqual(new.count("CODE_SIGN_STYLE = Manual;"), 2)
        # Undo only the expected substitutions: all other targets/settings stay exact.
        restored = new
        for uuid in profiles.values():
            replacement = ('CODE_SIGN_STYLE = Manual;\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";\n'
                           f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{uuid}";')
            restored = restored.replace(replacement, "CODE_SIGN_STYLE = Automatic;")
        self.assertEqual(restored, old)

    def test_unexpected_project_fails(self):
        with self.assertRaises(ValueError):
            configure_project("not a project", {APP_ID: UUID, TOP_ID: UUID})

    def test_export_is_internal_only_with_distinct_profiles(self):
        profiles = {APP_ID: UUID, TOP_ID: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"}
        options = export_options(TEAM, profiles)
        self.assertIs(options["testFlightInternalTestingOnly"], True)
        self.assertIs(options["manageAppVersionAndBuildNumber"], False)
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["provisioningProfiles"], profiles)


if __name__ == "__main__":
    unittest.main()
