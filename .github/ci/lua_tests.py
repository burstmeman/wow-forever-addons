"""Run one addon directory's Lua 5.1 specs against its WoW UI double.

Each addon's tests/run.py calls run_suite(). The locale matrix, Lupa startup,
and ADDON_RUNTIME_PATH handling live here, so a new directory does not copy
them. Specs listed in `specs` share one Lua state and run in that order.
Specs listed in `once` run a single time on the last of those states.
"""
from pathlib import Path
import os
import sys

REPO = Path(__file__).resolve().parents[1]
LOCALES = ("enUS", "ruRU", "esES", "esMX", "deDE", "frFR", "enGB", "koKR")


def suite_files(addon_dir, specs, once=()):
    """Return the mock and spec paths, rejecting names that leave tests/."""
    tests = Path(addon_dir).resolve() / "tests"
    mock = tests / "wow_mock.lua"
    if not mock.is_file():
        raise ValueError(f"Missing WoW UI double: {mock}")

    def existing(names):
        paths = []
        for name in names:
            path = tests / name
            if path.parent != tests or not path.is_file():
                raise ValueError(f"Missing spec: {name}")
            paths.append(path)
        return paths

    spec_paths = existing(specs)
    once_paths = existing(once)
    if once_paths and not spec_paths:
        raise ValueError("A one-shot spec needs the locale matrix to build the UI double")
    if not spec_paths and not once_paths:
        raise ValueError(f"No specs listed for {tests}")
    return mock, spec_paths, once_paths


def run_suite(addon_dir, specs, once=()):
    addon_dir = Path(addon_dir).resolve()
    mock, spec_paths, once_paths = suite_files(addon_dir, specs, once)
    runtime = REPO / ".tools" / "lua-test-runtime"
    if runtime.is_dir() and str(runtime) not in sys.path:
        sys.path.insert(0, str(runtime))
    try:
        from lupa.lua51 import LuaRuntime
    except ImportError:
        raise SystemExit("Lua 5.1 runtime missing. Install lupa==2.8 with Python 3.12.") from None

    mock_source = mock.read_text(encoding="utf-8")
    spec_sources = [path.read_text(encoding="utf-8") for path in spec_paths]
    once_sources = [path.read_text(encoding="utf-8") for path in once_paths]
    runtime_path = Path(os.environ.get("ADDON_RUNTIME_PATH", addon_dir)).resolve().as_posix()
    lua = None
    for locale in LOCALES:
        for legacy in (False, True):
            lua = LuaRuntime(unpack_returned_tuples=True, register_eval=False, register_builtins=False)
            lua.execute("assert(python.eval == nil and python.builtins == nil)")
            lua.globals().ADDON_PATH = runtime_path
            lua.globals().TEST_LOCALE = locale
            lua.globals().TEST_LEGACY = legacy
            lua.execute(mock_source)
            for source in spec_sources:
                lua.execute(source)
            names = ", ".join(path.stem for path in spec_paths)
            print(f"PASS: {locale}, legacy={legacy}: {names}")
    for path, source in zip(once_paths, once_sources):
        lua.execute(source)
        print(f"PASS: {path.stem}")
