"""Exercise the addon in Lua 5.1 with a stateful WoW UI double."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
runtime = ROOT / ".tools" / "lua-test-runtime"
if runtime.is_dir():
    sys.path.insert(0, str(runtime))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.exit("Lua 5.1 runtime missing. Install lupa==2.6 with Python 3.12.")

for locale, legacy in (("enUS", False), ("ruRU", False), ("enUS", True), ("ruRU", True)):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ADDON_PATH = ROOT.joinpath("CompactAddonButtons").as_posix()
    lua.globals().TEST_LOCALE = locale
    lua.globals().TEST_LEGACY = legacy
    lua.execute(Path(__file__).with_name("addon_spec.lua").read_text(encoding="utf-8"))
    print(f"PASS: {locale}, legacy={legacy}: lifecycle, popup layout/anchors, settings, restoration, combat")
