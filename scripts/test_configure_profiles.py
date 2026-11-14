#!/usr/bin/env python3
"""Static identity-transform regression tests; does not mutate the working tree."""
import importlib.util
import tempfile
import subprocess
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("configure", Path(__file__).with_name("configure_profiles.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class IdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # Read immutable baseline files, so the tests work before AND after configuration.
        files = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", "71b3b2cce53cdf5c5b0ebd83f771d938f9e7264c"], cwd=mod.ROOT, text=True)
        for name in files.splitlines():
            if Path(name).suffix in (".swift", ".plist", ".entitlements", ".pbxproj", ".yml"):
                target = self.root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(subprocess.check_output(["git", "show", "71b3b2cce53cdf5c5b0ebd83f771d938f9e7264c:" + name], cwd=mod.ROOT))

    def test_dry_run_is_isolated_and_consistent(self):
        changes = mod.plan(self.root, "com.example.yatteeprofiles", "yatteeprofiles")
        self.assertGreater(len(changes), 10)
        for path, text in changes.items():
            if text is not None:
                self.assertNotIn("stream.yattee.app", text, str(path))
                self.assertNotIn('"yattee"', text, str(path))
                self.assertNotIn("yattee://", text, str(path))
        project = changes[self.root / "Yattee.xcodeproj/project.pbxproj"]
        self.assertIn('PRODUCT_BUNDLE_IDENTIFIER = com.example.yatteeprofiles.TopShelf;', project)
        self.assertIn('INFOPLIST_KEY_CFBundleDisplayName = "Yattee Profiles";', project)
        self.assertNotIn("DEVELOPMENT_TEAM = 78Z5H3M6RJ", project)
        app_group = changes[self.root / "Yattee/Core/AppGroup.swift"]
        self.assertIn('group.com.example.yatteeprofiles.shared', app_group)
        self.assertIn('group.com.example.yatteeprofiles.shared', changes[self.root / "YatteeTopShelf/AppGroup.swift"])
        self.assertIsNone(changes[self.root / ".github/workflows/release.yml"])
        # Dry-run source must remain original.
        self.assertIn("stream.yattee.app", (self.root / "Yattee/Core/AppIdentifiers.swift").read_text())

    def test_rejects_upstream_identity_and_bad_arguments(self):
        for bundle, scheme in [
            ("stream.yattee.app", "yatteeprofiles"),
            ("com.example.foo", "yattee"),
            ("../escape", "yatteeprofiles"),
        ]:
            with self.assertRaises(ValueError):
                mod.plan(self.root, bundle, scheme)

if __name__ == "__main__":
    unittest.main()
