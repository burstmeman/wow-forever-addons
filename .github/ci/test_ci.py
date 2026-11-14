"""Exercise routing and security policies without executing addon code."""
import copy
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

import addons
import security


class RoutingTests(unittest.TestCase):
    def test_packaged_tests_receive_extracted_runtime_without_reinstalling_dependencies(self):
        addon = {"path": "Example", "tests": {"command": ["python", "tests/run.py"], "requirements": "tests/requirements.txt"}}
        with tempfile.TemporaryDirectory() as directory, patch.object(addons.subprocess, "run") as run:
            addons.run_tests(addon, runtime_path=Path(directory))
            run.assert_called_once()
            self.assertEqual(run.call_args.kwargs["env"]["ADDON_RUNTIME_PATH"], str(Path(directory).resolve()))
            self.assertEqual(run.call_args.args[0][1:], ["tests/run.py"])

    def setUp(self):
        self.addons = [
            {"name": "One", "path": "One", "manifest": "One.toc", "status": "development"},
            {"name": "Two", "path": "nested/Two", "manifest": "Two.toc", "status": "experiment"},
        ]

    def selected(self, paths, previous=None):
        return [a["name"] for a in addons.select(self.addons, paths, previous or self.addons)]

    def test_only_changed_addon(self):
        self.assertEqual(self.selected(["One/UI.lua"]), ["One"])
        self.assertEqual(self.selected(["nested/Two/removed.lua"]), ["Two"])
        self.assertEqual(self.selected(["One/file", "nested/Two/new.lua"]), ["One", "Two"])

    def test_unrelated_and_prefix_paths(self):
        self.assertEqual(self.selected(["README.md", "OneExtra/file.lua"]), [])

    def test_shared_ci_affects_every_addon(self):
        self.assertEqual(self.selected([".github/ci/addons.py"]), ["One", "Two"])

    def test_config_changes_only_affected_entry(self):
        previous = copy.deepcopy(self.addons)
        previous[0]["status"] = "experiment"
        self.assertEqual(self.selected(["addons.yml"], previous), ["One"])
        self.assertEqual(self.selected(["addons.yml"]), [])

    def test_new_registration_is_selected(self):
        self.assertEqual(self.selected(["addons.yml"], self.addons[:1]), ["Two"])

    def test_paths_cannot_escape(self):
        for path in ("../x", "/tmp/x", "x/../y", "x\\y", ".", ""):
            with self.subTest(path=path), self.assertRaises(ValueError):
                addons.inside(addons.ROOT, path)

    def test_unregistered_manifest_fails(self):
        with self.assertRaisesRegex(ValueError, "Unregistered"):
            addons.validate([], ["New/New.toc"])

    def test_registry_validates_status_and_tests(self):
        data = {"schema": 1, "addons": self.addons}
        import yaml
        self.assertEqual(len(addons.parse_config(yaml.safe_dump(data))), 2)
        for change in ({"status": "released"}, {"status": "release"}, {"path": "../One"},
                       {"tests": {"command": "python test.py"}}, {"version": "duplicate"}):
            changed = copy.deepcopy(data)
            changed["addons"][0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                addons.parse_config(yaml.safe_dump(changed))

    def test_registration_detects_manifest_and_tests(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            previous_root, previous_config = addons.ROOT, addons.CONFIG
            addons.ROOT, addons.CONFIG = root, root / "addons.yml"
            try:
                addons.CONFIG.write_text("schema: 1\naddons: []\n", encoding="utf-8")
                (root / "New/tests").mkdir(parents=True)
                (root / "New/New.toc").write_text("## Version: 1.0\n", encoding="utf-8")
                (root / "New/tests/run.py").write_text("", encoding="utf-8")
                (root / "New/tests/requirements.txt").write_text("", encoding="utf-8")
                addons.register("New", "beta")
                entry = addons.registry()[0]
                self.assertEqual(entry["tests"]["command"], ["python", "tests/run.py"])
                self.assertEqual(entry["tests"]["requirements"], "tests/requirements.txt")
                with self.assertRaises(ValueError):
                    addons.register("New", "beta")
            finally:
                addons.ROOT, addons.CONFIG = previous_root, previous_config


class PolicyTests(unittest.TestCase):
    def test_direct_and_aliased_capabilities(self):
        for code in ('SendChatMessage(secret)', 'local send = SendAddonMessage; send(secret)',
                     'loadstring(payload)()', 'local run = os.execute', 'C_ChatInfo.SendAddonMessage(secret)',
                     'local env = _G', '_G[key](data)', '_G["Send" .. "ChatMessage"](data)',
                     '_G["SendChatMessage"](data)', 'getfenv()[key](data)', 'rawget(_G, key)',
                     'local payload = "\\083\\101\\110\\100"', 'local url = "https://example.invalid"'):
            with self.subTest(code=code):
                self.assertTrue(security.inspect_source(code))

    def test_comments_and_ui_code(self):
        self.assertFalse(security.inspect_source('-- SendChatMessage\n--[=[ loadstring _G ]=]\nlocal x = math.max(1, 2)'))
        code = '_G["ApprovedScrollBar"]:Hide()'
        self.assertFalse(security.inspect_source(code, ["ApprovedScrollBar"]))
        self.assertTrue(security.inspect_source(code))

    def test_long_strings_and_lint_bypass(self):
        self.assertTrue(security.inspect_source('local x = [=[https://example.invalid]=]'))
        self.assertTrue(security.inspect_source('-- luacheck: ignore 113'))
        with self.assertRaises(ValueError):
            security.inspect_source('local x = "unterminated')

    def test_manifest_cannot_load_tests_or_external_code(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            previous_root = security.ROOT
            security.ROOT = root
            try:
                (root / "Test").mkdir()
                manifest = root / "Test/Test.toc"
                for entry in ("../payload.lua", "tests/runner.lua", "hidden.xml", "missing.lua"):
                    manifest.write_text(entry, encoding="utf-8")
                    with self.subTest(entry=entry), self.assertRaises(ValueError):
                        security.runtime_files({"path": "Test", "manifest": "Test.toc"})
            finally:
                security.ROOT = previous_root


if __name__ == "__main__":
    unittest.main()
