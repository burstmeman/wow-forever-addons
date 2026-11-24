"""Checksum-pinned StyLua. The shared stylua.toml is the only style authority."""
import hashlib
import io
import os
from pathlib import Path
import platform
import re
import stat
import subprocess
import sys
import urllib.request
import zipfile

from addons import ROOT, inside, registry

VERSION = "2.6.0"
MAX_BYTES = 8 * 1024 * 1024
CONFIG = ROOT / "stylua.toml"
CACHE = ROOT / ".tools" / "stylua"
DIRECTIVE = re.compile(r"stylua\s*:", re.I)
ASSETS = {
    ("Linux", "x86_64"): (
        "stylua-linux-x86_64.zip",
        "a485f72bbfa22e4642e77a84b5edc2611a5cab7477b34e2e709dd8f78e919895",
    ),
    ("Linux", "arm64"): (
        "stylua-linux-aarch64.zip",
        "8e67539e5fdf7a81cd03cf592b0df18d3bb96ee17a5ea5d9bf67b86387b903b0",
    ),
    ("Darwin", "arm64"): (
        "stylua-macos-aarch64.zip",
        "dab9b66d340ca5ffc8225211f1dcf89b84783e09b8cbec8c518497eba81f3c42",
    ),
    ("Darwin", "x86_64"): (
        "stylua-macos-x86_64.zip",
        "90779aa873837b2dff8eb3361bd27950303914c24265a59cae0a0d0629d71585",
    ),
    ("Windows", "x86_64"): (
        "stylua-windows-x86_64.zip",
        "fd13b4014e3b779c244bbc03f2c282e357f15bc526de6a6fa5ecbc447538313c",
    ),
}


def machine():
    name = platform.machine().lower()
    if name in {"amd64", "x86_64"}:
        return "x86_64"
    if name in {"arm64", "aarch64"}:
        return "arm64"
    return name


def asset():
    key = (platform.system(), machine())
    if key not in ASSETS:
        raise ValueError(f"No pinned StyLua binary for {key[0]} {key[1]}")
    return ASSETS[key]


def binary_name():
    return "stylua.exe" if platform.system() == "Windows" else "stylua"


def verified_archive(data, digest):
    if len(data) > MAX_BYTES or hashlib.sha256(data).hexdigest() != digest:
        raise ValueError("StyLua archive checksum mismatch")
    return data


def extract_binary(data, destination, expected_name):
    """Write the one expected executable. Never use a path from the archive."""
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        members = archive.infolist()
        if len(members) != 1:
            raise ValueError("Unexpected StyLua archive entry")
        member = members[0]
        name = member.filename.replace("\\", "/")
        mode = member.external_attr >> 16
        if name != expected_name or member.is_dir() or stat.S_ISLNK(mode):
            raise ValueError("Unexpected StyLua archive entry")
        payload = archive.read(member)
    if not payload:
        raise ValueError("Unexpected StyLua archive entry")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    if os.name != "nt":
        destination.chmod(0o755)
    return destination


def download(url):
    chunks, total = [], 0
    with urllib.request.urlopen(url, timeout=60) as response:
        while total <= MAX_BYTES:
            block = response.read(64 * 1024)
            if not block:
                break
            total += len(block)
            chunks.append(block)
    return b"".join(chunks)


def setup():
    name, digest = asset()
    CACHE.mkdir(parents=True, exist_ok=True)
    archive_path = CACHE / name
    if archive_path.is_file():
        data = verified_archive(archive_path.read_bytes(), digest)
    else:
        url = f"https://github.com/JohnnyMorganz/StyLua/releases/download/v{VERSION}/{name}"
        data = verified_archive(download(url), digest)
        archive_path.write_bytes(data)
    binary = extract_binary(data, CACHE / VERSION / binary_name(), binary_name())
    print(f"StyLua {VERSION}: verified archive SHA-256")
    return binary


def lua_files(addon):
    root = inside(ROOT, addon["path"])
    files = []
    for path in sorted(root.rglob("*.lua")):
        if path.is_file():
            files.append(inside(root, path.relative_to(root).as_posix()))
    if not files:
        raise ValueError(f"No Lua files found in {addon['name']}")
    return files


def selected(name):
    addons = registry()
    if name is None:
        return addons
    match = [addon for addon in addons if addon["name"] == name]
    if not match:
        raise ValueError("Unknown addon identifier")
    return match


def display_path(path):
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT)
    except ValueError:
        return resolved


def directive_violations(files):
    violations = []
    for path in files:
        if DIRECTIVE.search(path.read_text(encoding="utf-8-sig")):
            violations.append(f"{display_path(path)}: inline StyLua directives are not allowed")
    return violations


def stylua_command(binary, files, check):
    command = [str(binary), "--config-path", str(CONFIG), "--no-editorconfig", "--syntax", "Lua51"]
    if check:
        command.append("--check")
    command.extend(str(path) for path in files)
    return command


def format_addons(check, name=None):
    files = []
    for addon in selected(name):
        files.extend(lua_files(addon))
    violations = directive_violations(files)
    if violations:
        raise ValueError("\n".join(violations))
    result = subprocess.run(stylua_command(setup(), files, check), check=False)
    if result.returncode:
        raise SystemExit(result.returncode)
    action = "matches" if check else "rewrote"
    print(f"StyLua {VERSION}: {action} {len(files)} Lua files")


def main(argv):
    if argv == ["setup"]:
        setup()
        return
    if len(argv) in {1, 2} and argv[0] in {"check", "fix"}:
        format_addons(check=argv[0] == "check", name=argv[1] if len(argv) == 2 else None)
        return
    raise SystemExit("Usage: python .github/ci/lua_format.py setup|check [Addon]|fix [Addon]")


if __name__ == "__main__":
    main(sys.argv[1:])
