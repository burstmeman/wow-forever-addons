"""Test version increments, generated choices, and the version-PR release boundary."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import addons
import next_release as next_release


class FakeAPI:
    repo = "owner/repo"

    def __init__(self):
        self.files, self.branches, self.tags, self.releases, self.dispatches = {}, {}, {}, {}, []
        self.commits = 0
        self.addon = {"name": "Example", "path": "Example", "manifest": "Example.toc", "status": "release", "release": {"files": ["*.toc"]}}
        self.pr = None

    def text(self, path, ref, optional=False):
        if path == "Example/Example.toc":
            return "## Author: burstmeman\r\n## Version: " + ("1.2.9" if ref == "d" * 40 else "1.2.8") + "\r\nMain.lua\r\n"
        if path == "Example/README.md":
            return "# Example\nVersion **1.2.8**.\n"
        if path == "release-requests/Example.json":
            return self.files[path]
        raise AssertionError(path)

    def optional(self, path):
        if path.startswith("/git/ref/heads/"):
            return self.branches.get(path.removeprefix("/git/ref/heads/"))
        if path.startswith("/git/ref/tags/"):
            return self.tags.get(path.removeprefix("/git/ref/tags/"))
        if path.startswith("/releases/tags/"):
            return self.releases.get(path.removeprefix("/releases/tags/").replace("%2F", "/"))
        raise AssertionError(path)

    def call(self, path, method="GET", payload=None):
        if path == "/branches/main":
            return {"commit": {"sha": "a" * 40, "commit": {"tree": {"sha": "c" * 40}}}}
        if path == "/git/trees":
            self.files = {f["path"]: f["content"] for f in payload["tree"]}
            return {"sha": "e" * 40}
        if path == "/git/commits":
            self.commits += 1
            assert "Co-authored-by" not in payload["message"]
            return {"sha": "b" * 40}
        if path == "/git/refs":
            target = self.branches if payload["ref"].startswith("refs/heads/") else self.tags
            target[payload["ref"].split("/", 2)[2]] = {"object": {"type": "commit", "sha": payload["sha"]}}
            return {}
        if path == "/pulls" and method == "POST":
            self.pr = {"number": 1, "html_url": "https://github.com/owner/repo/pull/1", "merged": False,
                "user": {"login": "github-actions[bot]"}, "base": {"ref": "main"},
                "head": {"ref": payload["head"], "sha": "b" * 40, "repo": {"full_name": self.repo}}, "merge_commit_sha": "d" * 40}
            return self.pr
        if path.startswith("/pulls?state=open"):
            return [self.pr]
        if path == "/pulls/1":
            return self.pr
        if path.startswith("/compare/"):
            return {"files": [{"filename": p, "sha": next_release.blob_sha(c)} for p, c in self.files.items()]}
        if path == "/releases":
            self.releases[payload["tag_name"]] = {"id": 1}
            return {"id": 1}
        if path == "/actions/workflows/release.yml/dispatches":
            self.dispatches.append(payload)
            return None
        raise AssertionError((path, method))


class NextReleaseTests(unittest.TestCase):
    def setUp(self):
        self.api = FakeAPI()
        self.patch = patch.object(next_release, "registry", return_value=[self.api.addon])
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def prepare(self):
        return next_release.create_request(self.api, "Example", "patch", "Fixed popup input.")

    def test_next_versions(self):
        self.assertEqual(next_release.next_version("1.2.8", "patch"), "1.2.9")
        self.assertEqual(next_release.next_version("1.2.8", "minor"), "1.3.0")
        self.assertEqual(next_release.next_version("1.2.8", "major"), "2.0.0")
        for version, bump in (("01.2.3", "patch"), ("1.2.3-beta.1", "patch"), ("1.2", "patch"), ("1.2.3", "custom")):
            with self.subTest(version=version, bump=bump), self.assertRaises(ValueError):
                next_release.next_version(version, bump)

    def test_only_versions_and_request_metadata_change(self):
        self.prepare()
        self.assertEqual(set(self.api.files), {"Example/Example.toc", "Example/README.md", "release-requests/Example.json"})
        self.assertEqual(self.api.files["Example/Example.toc"], "## Author: burstmeman\r\n## Version: 1.2.9\r\nMain.lua\r\n")
        self.assertIn("Version **1.2.9**", self.api.files["Example/README.md"])
        intent = json.loads(self.api.files["release-requests/Example.json"])
        self.assertEqual(intent["tag"], "Example/v1.2.9")
        self.assertEqual(self.api.tags, {})
        self.assertEqual(self.api.dispatches, [])

    def test_repeated_button_press_reuses_open_pr(self):
        first = self.prepare()
        second = self.prepare()
        self.assertEqual(first["number"], second["number"])
        self.assertEqual(self.api.commits, 1)

    def test_merge_creates_tag_and_dispatches_publication(self):
        self.prepare()
        self.api.pr["merged"] = True
        next_release.finalize(self.api, {"number": 1})
        self.assertEqual(self.api.tags["Example/v1.2.9"]["object"]["sha"], "d" * 40)
        self.assertEqual(self.api.dispatches, [{"ref": "main", "inputs": {"tag": "Example/v1.2.9", "publish": "true"}}])

    def test_extra_code_cannot_be_auto_released(self):
        self.prepare()
        self.api.pr["merged"] = True
        self.api.files["Example/Main.lua"] = "unexpected code"
        with self.assertRaisesRegex(ValueError, "beyond"):
            next_release.finalize(self.api, {"number": 1})
        self.assertEqual(self.api.tags, {})
        self.assertEqual(self.api.dispatches, [])

    def test_non_bot_fork_and_unmerged_requests_fail(self):
        self.prepare()
        original = copy.deepcopy(self.api.pr)
        for mutation in (lambda p: None, lambda p: p.update(merged=True, user={"login": "someone"}),
                         lambda p: p.update(merged=True, head={**p["head"], "repo": {"full_name": "other/repo"}})):
            self.api.pr = copy.deepcopy(original)
            mutation(self.api.pr)
            with self.assertRaises(ValueError):
                next_release.finalize(self.api, {"number": 1})

    def test_refuses_to_move_an_existing_tag(self):
        self.prepare()
        self.api.pr["merged"] = True
        self.api.tags["Example/v1.2.9"] = {"object": {"type": "commit", "sha": "f" * 40}}
        with self.assertRaisesRegex(ValueError, "different commit"):
            next_release.finalize(self.api, {"number": 1})

    def test_dropdown_matches_registry(self):
        addons.sync_release_choices(check=True)

    def test_dropdown_generation_and_staleness_detection(self):
        with tempfile.TemporaryDirectory() as directory:
            workflow = Path(directory) / "workflow.yml"
            workflow.write_text("        # BEGIN ADDON CHOICES\n          - Old\n        # END ADDON CHOICES\n", encoding="utf-8")
            entries = [{"name": "One"}, {"name": "Two"}]
            with self.assertRaisesRegex(ValueError, "stale"):
                addons.sync_release_choices(entries, workflow, check=True)
            addons.sync_release_choices(entries, workflow)
            addons.sync_release_choices(entries, workflow, check=True)
            self.assertIn("          - Two\n", workflow.read_text())


if __name__ == "__main__":
    unittest.main()
