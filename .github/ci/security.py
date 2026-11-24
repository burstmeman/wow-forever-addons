"""Payload and environment checks that Luacheck does not parse.

Luacheck, using .github/ci/luacheckrc, owns syntax and the global allowlist.
This module owns the remaining review rules: literal `_G` lookups, network
URLs, encoded string payloads, and inline lint directives.
"""
import re
import subprocess
import sys

from addons import ROOT, inside, registry

LUACHECKRC = ROOT / ".github/ci/luacheckrc"
LONG = re.compile(r"\[(=*)\[")


def tokens(source):
    """Read Lua names/strings while excluding both short and long comments."""
    index = 0
    while index < len(source):
        if source[index].isspace():
            index += 1
            continue
        start = index
        comment = source.startswith("--", index)
        if comment:
            index += 2
        long = LONG.match(source, index)
        if long:
            end = source.find("]" + long[1] + "]", long.end())
            if end < 0:
                raise ValueError("Unterminated Lua long string/comment")
            index = end + len(long[1]) + 2
            if not comment:
                yield ("string", source[long.end():end], start)
            continue
        if comment:
            end = source.find("\n", index)
            index = len(source) if end < 0 else end + 1
            continue
        if source[index] in "\"'":
            quote = source[index]
            index += 1
            content = index
            while index < len(source) and source[index] != quote:
                index += 2 if source[index] == "\\" else 1
            if index >= len(source):
                raise ValueError("Unterminated Lua string")
            yield ("string", source[content:index], start)
            index += 1
        else:
            name = re.match(r"[A-Za-z_][A-Za-z0-9_]*", source[index:])
            value = name[0] if name else source[index]
            yield ("name" if name else "symbol", value, start)
            index += len(value)


def inspect_source(source, global_lookups=()):
    result = []
    stream = list(tokens(source))
    for index, (kind, value, offset) in enumerate(stream):
        reason = None
        if kind == "name" and value == "_G":
            tail = stream[index + 1:index + 4]
            if len(tail) != 3 or tail[0][1] != "[" or tail[1][0] != "string" or tail[1][1] not in global_lookups or tail[2][1] != "]":
                reason = "global environment access must use an explicitly allowed literal key"
        elif kind == "string" and (re.search(r"https?://", value, re.I) or re.search(r"\\(?:[0-9]|x[0-9a-fA-F])", value)):
            reason = "network URL or encoded string payload requires review"
        if reason:
            result.append((source.count("\n", 0, offset) + 1, reason))
    if re.search(r"luacheck\s*:", source, re.I):
        result.append((1, "inline lint overrides are not allowed in runtime code"))
    return result


def luacheck_command(files, allowances):
    """Lint with the shared config so an addon .luacheckrc cannot replace it."""
    exports = ["SlashCmdList", *allowances.get("globals", [])]
    return ["luacheck", *map(str, files), "--config", str(LUACHECKRC), "--no-default-config",
            "--only", "0", "1", "--globals", *exports]


def runtime_files(addon):
    root = inside(ROOT, addon["path"])
    manifest = inside(root, addon["manifest"])
    lines = manifest.read_text(encoding="utf-8-sig").splitlines()
    for line in lines:
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        path = inside(root, entry)
        if path.suffix != ".lua" or path.relative_to(root).parts[0] == "tests" or not path.is_file():
            raise ValueError(f"Manifest entry must be an existing runtime Lua file: {entry}")
    # Scan unlisted source too, so adding a payload to the manifest later cannot bypass review.
    return sorted(inside(root, p.relative_to(root).as_posix()) for p in root.rglob("*.lua")
                  if "tests" not in p.relative_to(root).parts)


def check(addon, lint=True):
    files = runtime_files(addon)
    if not files:
        raise ValueError("No runtime Lua files found")
    errors = []
    allowances = addon.get("security", {})
    for path in files:
        for line, reason in inspect_source(path.read_text(encoding="utf-8-sig"), allowances.get("global_lookups", [])):
            errors.append(f"{path.relative_to(ROOT)}:{line}: {reason}")
    if errors:
        raise ValueError("\n".join(errors))
    if lint:
        subprocess.run(luacheck_command(files, allowances), check=True)
    print(f"{addon['name']}: Lua API policy passed for {len(files)} runtime files")


if __name__ == "__main__":
    selected = next((a for a in registry() if a["name"] == sys.argv[1]), None)
    if selected is None:
        raise ValueError("Unknown addon identifier")
    check(selected)
