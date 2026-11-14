"""Exercise Lua token boundaries, literal preservation, and comment removal."""
import unittest

from lua_minify import minify


class LuaMinifyTests(unittest.TestCase):
    def test_comments_and_indentation_are_removed_without_joining_tokens(self):
        self.assertEqual(minify("-- heading\n  local --[[ explanation ]]\n x = 1\n  return x - -2 -- end\n"),
                         "local x = 1 return x - -2\n")
        self.assertEqual(minify("-- heading\rreturn 1 -- tail\r\n"), "return 1\n")

    def test_short_and_long_string_bytes_are_preserved(self):
        literal = r'''"a -- comment? \\"''' + "\n" + "[==[\nmultiline -- string\n[=[inner]=]\n]==]"
        self.assertEqual(minify(literal), literal.replace('"\n[', '" [') + "\n")
        self.assertEqual(minify("return 'a\\\nb'"), "return 'a\\\nb'\n")

    def test_operators_numbers_and_varargs_remain_unchanged(self):
        source = "local n=0xff+1.5e-3; return n .. .5, ..., a~=b, a<=b, a>=b"
        self.assertEqual(minify(source), source + "\n")
        self.assertEqual(minify("local x = - -- skip\n -1"), "local x = - -1\n")

    def test_unterminated_literals_fail_closed(self):
        for source in ('return "unfinished', "return [=[unfinished", "--[==[unfinished"):
            with self.subTest(source=source), self.assertRaises(ValueError):
                minify(source)
