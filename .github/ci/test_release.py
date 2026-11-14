"""Release routing, packaging, flavor resolution, and duplicate-upload protection."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import zipfile

import addons
import release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "dist"
        self.addon = {"name": "Example", "path": "Example", "manifest": "Example.toc", "status": "release",
                      "release": {"files": ["*.toc", "*.lua", "Media/*"], "curseforge": {
                          "project_id": 123, "game_version_type_id": 88568, "game_versions": ["1.60.1"]}}}
        (self.root / "Example/Media").mkdir(parents=True)
        (self.root / "Example/tests").mkdir()
        (self.root / "Example/Example.toc").write_text("## Version: 1.2.3\nMain.lua\n", encoding="utf-8")
        (self.root / "Example/Main.lua").write_text("local name = ...\n", encoding="utf-8")
        (self.root / "Example/Media/Icon.tga").write_bytes(b"texture")
        (self.root / "Example/tests/private.py").write_text("not shipped", encoding="utf-8")
        (self.root / "LICENSE").write_text("License text", encoding="utf-8")
        self.addCleanup(patch.stopall)
        patch.object(release, "ROOT", self.root).start()
        patch.object(release, "registry", return_value=[self.addon]).start()

    def test_per_addon_tag_and_version_validation(self):
        addon, version = release.target("Example/v1.2.3")
        self.assertEqual((addon["name"], version), ("Example", "1.2.3"))
        for tag in (None, "v1.2.3", "Other/v1.2.3", "Example/v1.2.3;echo", "Example/../../v1.2.3"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release.target(tag)
        with self.assertRaisesRegex(ValueError, "Tag version"):
            release.package(self.addon, "1.2.4", self.output)

    def test_reproducible_runtime_only_zip(self):
        archive = release.package(self.addon, "1.2.3", self.output)
        original = archive.read_bytes()
        with zipfile.ZipFile(archive) as bundle:
            self.assertEqual(set(bundle.namelist()), {"Example/Example.toc", "Example/Main.lua", "Example/Media/Icon.tga", "Example/LICENSE"})
            self.assertEqual(bundle.read("Example/Media/Icon.tga"), b"texture")
        self.assertEqual(release.package(self.addon, "1.2.3", self.output).read_bytes(), original)

    def test_missing_runtime_file_and_development_inclusion_fail(self):
        self.addon["release"]["files"] = ["*.toc"]
        with self.assertRaisesRegex(ValueError, "Manifest dependency"):
            release.package(self.addon, "1.2.3", self.output)
        self.addon["release"]["files"] = ["**/*"]
        with self.assertRaisesRegex(ValueError, "Development files"):
            release.package(self.addon, "1.2.3", self.output)

    def test_exact_forever_flavor_resolution(self):
        rows = [{"name": "1.60.1", "gameVersionTypeID": 517, "id": 1},
                {"name": "1.60.1", "gameVersionTypeID": 88568, "id": 2}]
        self.assertEqual(release.resolve_versions(rows, self.addon["release"]["curseforge"]), [2])
        for invalid in (rows[:1], rows + [rows[1]], []):
            with self.subTest(rows=invalid), self.assertRaises(ValueError):
                release.resolve_versions(invalid, self.addon["release"]["curseforge"])

    def test_release_channels(self):
        self.assertEqual(release.channel(self.addon, "1.2.3"), "release")
        self.assertEqual(release.channel(self.addon, "1.2.3-beta.1"), "beta")
        self.assertEqual(release.channel(self.addon, "1.2.3-rc.1"), "beta")
        self.assertEqual(release.channel(self.addon, "1.2.3-alpha.1"), "alpha")
        self.assertEqual(release.channel(self.addon, "1.2.3", True), "beta")
        self.addon["status"] = "experiment"
        self.assertEqual(release.channel(self.addon, "1.2.3"), "alpha")

    def test_config_rejects_unsafe_release_settings(self):
        import yaml
        valid = {"schema": 1, "addons": [{**self.addon, "status": "development"}]}
        addons.parse_config(yaml.safe_dump(valid))
        for field, value in (("project_id", True), ("project_id", 0), ("game_version_type_id", "88568"), ("game_versions", [])):
            data = copy.deepcopy(valid)
            data["addons"][0]["release"]["curseforge"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                addons.parse_config(yaml.safe_dump(data))

    def setup_publish(self, timeout=False):
        info = release.prepare("Example/v1.2.3", self.output, check_git=False)
        info["commit"] = "a" * 40
        (self.output / "release.json").write_text(json.dumps(info), encoding="utf-8")
        self.assets, self.uploads = [], []
        self.release = {"id": 10, "body": "Release notes", "prerelease": False, "draft": True}
        self.calls = []
        patch.object(release, "git", return_value="a" * 40).start()
        patch.object(release.subprocess, "run").start()
        patch.dict(os.environ, GITHUB_REPOSITORY="owner/repo", GITHUB_TOKEN="test-github", CURSE_FORGE_DEPLOYMENT_TOKEN="test-curseforge").start()

        def api(url, token, header, method="GET", payload=None, content_type="application/json"):
            self.calls.append((url, method, payload))
            if "/releases/tags/" in url:
                return self.release
            if url.endswith("/releases/10") and method == "PATCH":
                self.assertTrue(any(a["name"].startswith("curseforge-123-") for a in self.assets))
                self.assertFalse(any(a["name"].startswith("curseforge-pending-") for a in self.assets))
                self.release.update(payload)
                self.release["immutable"] = True
                return self.release
            if "/assets?per_page=" in url:
                return list(self.assets)
            if url.startswith("https://uploads.github.com/"):
                self.assertFalse(self.release.get("immutable"), "all assets must precede publication")
                name = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)["name"][0]
                item = {"id": len(self.assets) + 1, "name": name, "digest": "sha256:" + hashlib.sha256(payload).hexdigest()}
                self.assets.append(item)
                return item
            if method == "DELETE":
                self.assets[:] = [a for a in self.assets if a["id"] != int(url.rsplit("/", 1)[1])]
                return None
            if url.endswith("/api/game/wow/versions"):
                return [{"id": 99, "name": "1.60.1", "gameVersionTypeID": 88568}]
            if url.endswith("/upload-file"):
                self.assertTrue(any(a["name"].startswith("curseforge-pending-") for a in self.assets))
                self.assertEqual(header, "X-Api-Token")
                self.assertIn(b'"gameVersions": [99]', payload)
                self.assertIn(json.dumps({"changelog": self.release["body"]})[1:-1].encode(), payload)
                self.uploads.append(url)
                if timeout:
                    raise TimeoutError("Ambiguous response")
                return {"id": 456}
            raise AssertionError(f"Unexpected API request: {url}")
        patch.object(release, "request_json", side_effect=api).start()

    def test_receipt_prevents_tag_release_and_rerun_duplicates(self):
        self.setup_publish()
        release.publish(self.output)
        release.publish(self.output)
        self.assertEqual(len(self.uploads), 1)
        self.assertFalse(any(a["name"].startswith("curseforge-pending-") for a in self.assets))
        self.assertTrue(any(a["name"].startswith("curseforge-123-") for a in self.assets))
        self.assertTrue(self.release["immutable"])
        self.assertFalse(self.release["draft"])

    def test_immutable_release_without_receipt_fails_before_upload(self):
        self.setup_publish()
        self.release.update(draft=False, immutable=True)
        with self.assertRaisesRegex(ValueError, "already immutable"):
            release.publish(self.output)
        self.assertEqual(self.assets, [])
        self.assertEqual(self.uploads, [])

    def test_tag_only_release_is_created_as_draft(self):
        self.setup_publish()
        original = release.request_json.side_effect
        def missing_release(url, token, header, method="GET", payload=None, content_type="application/json"):
            if "/releases/tags/" in url:
                raise urllib.error.HTTPError(url, 404, "Not Found", {}, None)
            if "/releases?per_page=" in url:
                return []
            if url.endswith("/releases") and method == "POST":
                self.assertTrue(payload["draft"])
                self.release.update(payload)
                return self.release
            return original(url, token, header, method, payload, content_type)
        with patch.object(release, "request_json", side_effect=missing_release):
            release.publish(self.output)
        self.assertEqual(len(self.uploads), 1)
        self.assertTrue(self.release["immutable"])

    def test_pending_cleanup_failure_resumes_from_success_receipt(self):
        self.setup_publish()
        original = release.request_json.side_effect
        def fail_delete(url, token, header, method="GET", payload=None, content_type="application/json"):
            if method == "DELETE":
                raise TimeoutError("Pending marker cleanup failed")
            return original(url, token, header, method, payload, content_type)
        with patch.object(release, "request_json", side_effect=fail_delete):
            with self.assertRaises(TimeoutError):
                release.publish(self.output)
        release.publish(self.output)
        self.assertEqual(len(self.uploads), 1)
        self.assertTrue(self.release["immutable"])

    def test_publication_failure_can_resume_without_second_curseforge_upload(self):
        self.setup_publish()
        original = release.request_json.side_effect
        def fail_publish(url, token, header, method="GET", payload=None, content_type="application/json"):
            if method == "PATCH":
                raise TimeoutError("Publication response lost")
            return original(url, token, header, method, payload, content_type)
        with patch.object(release, "request_json", side_effect=fail_publish):
            with self.assertRaises(TimeoutError):
                release.publish(self.output)
        release.publish(self.output)
        self.assertEqual(len(self.uploads), 1)
        self.assertTrue(self.release["immutable"])

    def test_finds_drafts_missing_from_tag_endpoint(self):
        draft = {"id": 10, "tag_name": "Example/v1.2.3", "draft": True}
        def api(path):
            if path.startswith("/releases/tags/"):
                raise urllib.error.HTTPError("https://api.github.com", 404, "Not Found", {}, None)
            self.assertEqual(path, "/releases?per_page=100&page=1")
            return [draft]
        self.assertEqual(release.find_release(api, draft["tag_name"]), draft)

    def test_error_identifies_api_and_redacts_credentials(self):
        with patch.dict(os.environ, CURSE_FORGE_DEPLOYMENT_TOKEN="private-test-token"):
            error = urllib.error.HTTPError("https://uploads.github.com/repos/owner/repo/releases/10/assets?name=file.zip", 422,
                "Unprocessable Entity", {}, io.BytesIO(json.dumps({"message": "Cannot upload assets to an immutable release", "errors": ["private-test-token"]}).encode()))
            message = release.api_error_message(error)
        self.assertIn("uploads.github.com/repos/owner/repo/releases/10/assets", message)
        self.assertIn("HTTP 422", message)
        self.assertIn("immutable release", message)
        self.assertNotIn("private-test-token", message)
        self.assertNotIn("?name", message)

    def test_timeout_blocks_automatic_resubmission(self):
        self.setup_publish(timeout=True)
        with self.assertRaises(TimeoutError):
            release.publish(self.output)
        with self.assertRaisesRegex(ValueError, "uncertain outcome"):
            release.publish(self.output)
        self.assertEqual(len(self.uploads), 1)

    def test_tampered_artifact_fails_before_network(self):
        self.setup_publish()
        (self.output / "Example-1.2.3.zip").write_bytes(b"different")
        with self.assertRaisesRegex(ValueError, "hash/name mismatch"):
            release.publish(self.output)
        self.assertEqual(self.uploads, [])

    def test_api_redirects_are_not_followed(self):
        with self.assertRaisesRegex(ValueError, "redirect"):
            release.NoRedirect().redirect_request(None, None, 302, "Found", {}, "https://example.invalid/")


if __name__ == "__main__":
    unittest.main()
