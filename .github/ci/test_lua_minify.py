"""Exercise the pinned upstream minifier and its safety checks."""
import unittest
from unittest.mock import patch

from lua_minify import DRIVER, minify, verified_archive


class LuaMinifyTests(unittest.TestCase):
    def test_comments_and_indentation_are_removed(self):
        result = minify("-- heading\n  local x = 1\n  return x + 2 -- end\n")
        self.assertNotIn("heading", result)
        self.assertNotIn("--", result)
        self.assertIn("local x=1", result)
        self.assertIn("return x+2", result)
        self.assertEqual(minify("-- heading\rreturn 1 -- tail\r\n").strip(), "return 1")

    def test_short_and_long_string_bytes_are_preserved(self):
        short = r'''"a -- comment? \\"'''
        long = "[==[\nmultiline -- string\n[=[inner]=]\n]==]"
        result = minify("return " + short + ", " + long)
        self.assertIn(short, result)
        self.assertIn(long, result)
        self.assertIn("'a\\\nb'", minify("return 'a\\\nb'"))

    def test_operators_numbers_and_varargs_remain_unchanged(self):
        source = "local n=0xff+1.5e-3; return n .. .5, ..., a~=b, a<=b, a>=b"
        result = minify(source)
        for token in ("0xff", "1.5e-3", "...", "~=", "<=", ">="):
            self.assertIn(token, result)

    def test_unsafe_upstream_rewrite_is_rejected_by_equivalence_checks(self):
        # Version 1.0.0 can turn adjacent unary/binary minus into a comment.
        # Never ship that result or fall back to an unchecked custom minifier.
        with self.assertRaisesRegex(ValueError, "equivalence"):
            minify("local x=1; return x - -2")

    def test_unterminated_literals_fail_closed(self):
        for source in ('return "unfinished', "return [=[unfinished", "--[==[unfinished"):
            with self.subTest(source=source), self.assertRaises(ValueError):
                minify(source)

    def test_modified_dependency_is_rejected_before_execution(self):
        with self.assertRaisesRegex(ValueError, "checksum"):
            verified_archive(b"tampered upstream source package")

    def test_binary_equivalence_rejects_modified_instructions(self):
        altered = DRIVER.replace("equiv.binary(source, result)", "result='return 42'; equiv.binary(source, result)")
        with patch("lua_minify.DRIVER", altered), self.assertRaisesRegex(ValueError, "equivalence"):
            minify("return 1")
