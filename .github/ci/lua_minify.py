"""Run checksum-pinned upstream LuaSrcDiet under Lua 5.1; never parse Lua here."""
from functools import lru_cache
import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = "1.0.0-2"
URL = f"https://luarocks.org/luasrcdiet-{VERSION}.src.rock"
SHA256 = "e9e13738b56d3ebd1237410907f1940ebc1159df47548bfac5effaac431f4fb4"
CACHE = ROOT / ".tools/luasrcdiet"
ARCHIVE = CACHE / f"luasrcdiet-{VERSION}.src.rock"
MODULES = ("init", "equiv", "llex", "lparser", "optlex", "optparser", "utils")

# The API checks source equivalence; the binary checker also compares Lua 5.1
# instructions/constants while ignoring changed debug line data.
DRIVER = """
local source = ...
local diet = require 'luasrcdiet'
local result = diet.optimize({comments=true, whitespace=true, emptylines=true,
    eols=true, srcequiv=true}, source)
local equiv = require 'luasrcdiet.equiv'
local warnings = {}
equiv.init({}, require 'luasrcdiet.llex', warnings)
equiv.binary(source, result)
assert(not warnings.BIN_EQUIV, 'LuaSrcDiet binary equivalence check failed')
return result
"""


def verified_archive(data):
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError("LuaSrcDiet source package checksum mismatch")
    return data


def setup():
    CACHE.mkdir(parents=True, exist_ok=True)
    if not ARCHIVE.is_file():
        with urllib.request.urlopen(URL, timeout=60) as response:
            data = verified_archive(response.read(1024 * 1024))
        ARCHIVE.write_bytes(data)
    source_root()
    print(f"LuaSrcDiet {VERSION}: verified source package SHA-256")


@lru_cache(maxsize=1)
def source_root():
    if not ARCHIVE.is_file():
        raise ValueError("LuaSrcDiet is not prepared; run python .github/ci/lua_minify.py setup")
    data = verified_archive(ARCHIVE.read_bytes())
    destination = CACHE / VERSION
    # Select exact files from the verified nested archive; never extract paths,
    # symlinks, rockspec build commands, plugins or upstream tests.
    with zipfile.ZipFile(io.BytesIO(data)) as rock:
        with tarfile.open(fileobj=io.BytesIO(rock.read("luasrcdiet-1.0.0.tar.gz")), mode="r:gz") as bundle:
            names = [f"luasrcdiet/{name}.lua" for name in MODULES] + ["COPYRIGHT", "COPYRIGHT_Lua51"]
            for name in names:
                member = bundle.getmember("luasrcdiet-1.0.0/" + name)
                if not member.isfile():
                    raise ValueError("Unexpected LuaSrcDiet archive entry")
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(bundle.extractfile(member).read())
    return destination


def minify(source):
    root = source_root().as_posix()
    executable = shutil.which("lua5.1")
    if executable:
        environment = os.environ.copy()
        environment.pop("LUA_INIT", None)
        environment["LUA_PATH"] = root + "/?.lua;" + root + "/?/init.lua"
        environment["LUA_CPATH"] = ""
        script = "local optimize = function(...) " + DRIVER + " end; io.write(optimize(io.read('*a')))"
        result = subprocess.run([executable, "-e", script], input=source.encode("utf-8"),
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment, check=False)
        if result.returncode:
            raise ValueError("LuaSrcDiet failed syntax/equivalence validation")
        return result.stdout.decode("utf-8")
    # Windows development uses the same PUC Lua 5.1 through the test runtime.
    runtime = ROOT / ".tools/lua-test-runtime"
    if runtime.is_dir() and str(runtime) not in sys.path:
        sys.path.insert(0, str(runtime))
    try:
        from lupa.lua51 import LuaRuntime
    except ImportError:
        raise ValueError("Lua 5.1 is required; install lua5.1 or the Lupa 2.8 test runtime") from None
    lua = LuaRuntime(register_eval=False, register_builtins=False)
    lua.globals().DIET_PATH = root
    lua.execute("python=nil; package.path=DIET_PATH..'/?.lua;'..DIET_PATH..'/?/init.lua'; package.cpath=''")
    try:
        return lua.eval("function(...) " + DRIVER + " end")(source)
    except Exception:
        raise ValueError("LuaSrcDiet failed syntax/equivalence validation") from None


if __name__ == "__main__":
    if sys.argv[1:] != ["setup"]:
        raise SystemExit("Usage: python .github/ci/lua_minify.py setup")
    setup()
