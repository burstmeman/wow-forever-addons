"""Exercise routing and security policies without executing addon code."""
import copy
import re
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

import addons
import lua_tests
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


class SuiteTests(unittest.TestCase):
    def test_specs_stay_inside_the_addon_tests_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            addon = Path(directory) / "Example"
            tests = addon / "tests"
            tests.mkdir(parents=True)
            (tests / "wow_mock.lua").write_text("-- mock", encoding="utf-8")
            (tests / "addon_spec.lua").write_text("-- spec", encoding="utf-8")
            mock, specs, once = lua_tests.suite_files(addon, ["addon_spec.lua"])
            self.assertEqual(mock, (tests / "wow_mock.lua").resolve())
            self.assertEqual(specs, [(tests / "addon_spec.lua").resolve()])
            self.assertEqual(once, [])
            for name in ("../outside.lua", "nested/spec.lua", "missing_spec.lua"):
                with self.subTest(name=name), self.assertRaises(ValueError):
                    lua_tests.suite_files(addon, [name])

    def test_one_shot_spec_requires_the_locale_matrix(self):
        with tempfile.TemporaryDirectory() as directory:
            addon = Path(directory) / "Example"
            tests = addon / "tests"
            tests.mkdir(parents=True)
            (tests / "wow_mock.lua").write_text("-- mock", encoding="utf-8")
            (tests / "performance_spec.lua").write_text("-- once", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "locale matrix"):
                lua_tests.suite_files(addon, [], ["performance_spec.lua"])

    def test_registered_runners_delegate_without_hardcoding_the_directory(self):
        for addon in addons.registry():
            if not addon.get("tests"):
                continue
            text = (addons.ROOT / addon["path"] / "tests/run.py").read_text(encoding="utf-8")
            with self.subTest(addon=addon["name"]):
                self.assertIn("run_suite", text)
                self.assertNotIn(addon["name"], text)


class PolicyTests(unittest.TestCase):
    def test_environment_lookups_and_payloads(self):
        for code in ('local env = _G', '_G[key](data)', '_G["Send" .. "ChatMessage"](data)',
                     '_G["SendChatMessage"](data)', 'rawget(_G, key)',
                     'local payload = "\\083\\101\\110\\100"', 'local url = "https://example.invalid"'):
            with self.subTest(code=code):
                self.assertTrue(security.inspect_source(code))

    def test_global_names_are_left_to_luacheck(self):
        for code in ('SendChatMessage(secret)', 'local send = SendAddonMessage; send(secret)',
                     'loadstring(payload)()', 'local run = os.execute',
                     'C_ChatInfo.SendAddonMessage(secret)', 'getfenv()[key](data)'):
            with self.subTest(code=code):
                self.assertFalse(security.inspect_source(code))

    def test_shared_allowlist_excludes_capabilities(self):
        text = security.LUACHECKRC.read_text(encoding="utf-8")
        self.assertIn('std = "none"', text)
        self.assertIn("inline = false", text)
        names = set(re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', text))
        forbidden = """getfenv setfenv getglobal setglobal rawget rawset getmetatable setmetatable
            load loadstring loadfile dofile require module collectgarbage io os debug package python
            ffi socket http https RunScript RunMacro RunMacroText SendChatMessage SendAddonMessage
            BNSendWhisper BNSendGameData BNSendConversationMessage RegisterAddonMessagePrefix SendMail
            C_ChatInfo C_BattleNet C_Club C_HTTP""".split()
        self.assertFalse(names & set(forbidden))

    def test_luacheck_command_uses_the_shared_config_and_addon_exports(self):
        command = security.luacheck_command(["Addon/Main.lua"], {"globals": ["MyAddon"]})
        self.assertEqual(command[:2], ["luacheck", "Addon/Main.lua"])
        self.assertIn(str(security.LUACHECKRC), command)
        self.assertNotIn("--no-config", command)
        self.assertEqual(command[command.index("--globals") + 1:], ["SlashCmdList", "MyAddon"])

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
