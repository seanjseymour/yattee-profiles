#!/usr/bin/env python3
"""Exercise cloud signing setup against an isolated copy of the real project."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "ci_scripts/ci_post_clone.sh"


class CloudSigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "Yattee.xcodeproj/project.pbxproj"
        self.project.parent.mkdir()
        self.original = (ROOT / "Yattee.xcodeproj/project.pbxproj").read_text()
        self.project.write_text(self.original)

    def run_hook(self, cloud="TRUE", team="ABCDE12345"):
        return subprocess.run(
            ["sh", str(HOOK)], text=True, capture_output=True,
            env={**os.environ, "CI_XCODE_CLOUD": cloud, "CI_TEAM_ID": team,
                 "CI_PRIMARY_REPOSITORY_PATH": str(self.root)},
        )

    def test_cloud_changes_only_team_placeholders(self):
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.project.read_text(),
                         self.original.replace("$(YATTEE_PROFILES_TEAM)", "ABCDE12345"))

    def test_local_runs_do_not_change_project(self):
        result = self.run_hook(cloud="")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.project.read_text(), self.original)

    def test_invalid_or_missing_team_fails_without_writing(self):
        for team in ("", "bad/team", "$(OTHER_TEAM)"):
            with self.subTest(team=team):
                self.assertNotEqual(self.run_hook(team=team).returncode, 0)
                self.assertEqual(self.project.read_text(), self.original)


if __name__ == "__main__":
    unittest.main()
