"""Pin StyLua and keep addon config from replacing the shared style."""
import hashlib
import io
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

import addons
import lua_format


def archive(name, payload, mode=0o755):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as bundle:
        info = zipfile.ZipInfo(name)
        info.external_attr = mode << 16
        bundle.writestr(info, payload)
    return buffer.getvalue()


class LuaFormatTests(unittest.TestCase):
    def test_shared_config_is_lua51_with_four_space_indents(self):
        text = lua_format.CONFIG.read_text(encoding="utf-8")
        self.assertIn('syntax = "Lua51"', text)
        self.assertIn('indent_type = "Spaces"', text)
        self.assertIn("indent_width = 4", text)
        self.assertIn('line_endings = "Unix"', text)
        self.assertIn('collapse_simple_statement = "Always"', text)

    def test_checksum_and_size_are_rejected_before_extract(self):
        with self.assertRaisesRegex(ValueError, "checksum"):
            lua_format.verified_archive(b"tampered", "0" * 64)
        digest = hashlib.sha256(b"a" * (lua_format.MAX_BYTES + 1)).hexdigest()
        with self.assertRaisesRegex(ValueError, "checksum"):
            lua_format.verified_archive(b"a" * (lua_format.MAX_BYTES + 1), digest)

    def test_archive_must_contain_only_the_expected_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "stylua"
            lua_format.extract_binary(archive("stylua", b"binary"), destination, "stylua")
            self.assertEqual(destination.read_bytes(), b"binary")
            for name, payload, mode in (
                ("../stylua", b"binary", 0o755),
                ("stylua/extra", b"binary", 0o755),
                ("stylua", b"", 0o755),
                ("stylua", b"link", stat.S_IFLNK | 0o777),
            ):
                with self.subTest(name=name), self.assertRaisesRegex(ValueError, "archive entry"):
                    lua_format.extract_binary(archive(name, payload, mode), destination, "stylua")
            extra = io.BytesIO()
            with zipfile.ZipFile(extra, "w") as bundle:
                bundle.writestr("stylua", b"binary")
                bundle.writestr("README", b"extra")
            with self.assertRaisesRegex(ValueError, "archive entry"):
                lua_format.extract_binary(extra.getvalue(), destination, "stylua")

    def test_commands_force_the_shared_config(self):
        check = lua_format.stylua_command(Path("/opt/stylua"), [Path("A.lua")], check=True)
        self.assertEqual(check[:6], [
            "/opt/stylua", "--config-path", str(lua_format.CONFIG), "--no-editorconfig", "--syntax", "Lua51",
        ])
        self.assertEqual(check[6:], ["--check", "A.lua"])
        fix = lua_format.stylua_command(Path("/opt/stylua"), [Path("A.lua")], check=False)
        self.assertNotIn("--check", fix)
        self.assertEqual(fix[-1], "A.lua")

    def test_addon_selection_includes_tests_and_rejects_unknown_names(self):
        addon = next(item for item in addons.registry() if item["name"] == "CompactAddonButtons")
        relative = {path.relative_to(lua_format.ROOT).as_posix() for path in lua_format.lua_files(addon)}
        self.assertIn("CompactAddonButtons/Application.lua", relative)
        self.assertIn("CompactAddonButtons/tests/wow_mock.lua", relative)
        self.assertEqual(lua_format.selected(None), addons.registry())
        with self.assertRaisesRegex(ValueError, "Unknown addon"):
            lua_format.selected("Missing")

    def test_inline_directives_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Main.lua"
            path.write_text("local value = 1\n", encoding="utf-8")
            self.assertEqual(lua_format.directive_violations([path]), [])
            path.write_text("-- stylua: ignore\nlocal value = 1\n", encoding="utf-8")
            self.assertIn("inline StyLua directives", lua_format.directive_violations([path])[0])

    def test_workflows_check_formatting_and_do_not_rewrite_files(self):
        for name in ("ci.yml", "release.yml"):
            text = (lua_format.ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
            with self.subTest(workflow=name):
                self.assertIn("python .github/ci/lua_format.py setup", text)
                self.assertIn('python .github/ci/lua_format.py check "$ADDON"', text)
                self.assertNotIn("lua_format.py fix", text)
