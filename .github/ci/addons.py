"""Registry validation, changed-addon selection, registration, and test execution."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

import yaml

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "addons.yml"
STATUSES = {"release", "beta", "development", "experiment"}


def inside(root, relative):
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError(f"Invalid relative path: {relative!r}")
    path = PurePosixPath(relative)
    if path.is_absolute() or any(part in {".", ".."} for part in relative.split("/")):
        raise ValueError(f"Unsafe relative path: {relative!r}")
    resolved = (root / relative).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError(f"Path escapes its directory: {relative!r}")
    return resolved


def parse_config(text):
    data = yaml.safe_load(text)
    if not isinstance(data, dict) or set(data) != {"schema", "addons"} or data["schema"] != 1:
        raise ValueError("addons.yml must contain schema: 1 and an addons list")
    if not isinstance(data["addons"], list):
        raise ValueError("addons must be a list")
    names, paths = set(), []
    for addon in data["addons"]:
        if not isinstance(addon, dict) or set(addon) - {"name", "path", "manifest", "status", "tests", "security", "release"}:
            raise ValueError("Unknown addon configuration fields")
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", addon.get("name", "")):
            raise ValueError("Addon names must be stable identifiers")
        if addon["name"] in names:
            raise ValueError("Duplicate addon name")
        names.add(addon["name"])
        path = addon.get("path")
        inside(ROOT, path)
        if any(path == old or path.startswith(old + "/") or old.startswith(path + "/") for old in paths):
            raise ValueError("Addon paths must not overlap")
        paths.append(path)
        release = addon.get("release")
        if release is not None:
            if not isinstance(release, dict) or set(release) != {"files", "curseforge"}:
                raise ValueError("release must contain files and curseforge")
            patterns = release["files"]
            if not isinstance(patterns, list) or not patterns:
                raise ValueError("release.files must be a nonempty glob list")
            for pattern in patterns:
                inside(ROOT / path, pattern)
            cf = release["curseforge"]
            if not isinstance(cf, dict) or set(cf) != {"project_id", "game_version_type_id", "game_versions"}:
                raise ValueError("Invalid CurseForge release configuration")
            for key in ("project_id", "game_version_type_id"):
                if type(cf[key]) is not int or cf[key] <= 0:
                    raise ValueError(f"curseforge.{key} must be a positive integer")
            if not isinstance(cf["game_versions"], list) or not cf["game_versions"] or not all(
                isinstance(v, str) and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", v) for v in cf["game_versions"]
            ):
                raise ValueError("curseforge.game_versions must list exact game version names")
        if addon.get("status") not in STATUSES:
            raise ValueError("Invalid addon status")
        manifest = addon.get("manifest")
        inside(ROOT / path, manifest)
        if not manifest.endswith(".toc"):
            raise ValueError("The manifest must be a .toc file")
        tests = addon.get("tests")
        if tests is None and addon["status"] in {"release", "beta"}:
            raise ValueError("Release and beta addons must declare tests")
        if tests is not None:
            if not isinstance(tests, dict) or set(tests) - {"command", "requirements"}:
                raise ValueError("Invalid tests configuration")
            command = tests.get("command")
            if not isinstance(command, list) or not command or not all(isinstance(x, str) and x for x in command):
                raise ValueError("tests.command must be a nonempty argument list, not a shell command")
            if "requirements" in tests:
                inside(ROOT / path, tests["requirements"])
        security = addon.get("security", {})
        if not isinstance(security, dict) or set(security) - {"globals", "global_lookups"}:
            raise ValueError("Invalid security configuration")
        for values in security.values():
            if not isinstance(values, list) or not all(isinstance(x, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", x) for x in values):
                raise ValueError("Security allowances must be lists of identifiers")
    return data["addons"]


def registry():
    return parse_config(CONFIG.read_text(encoding="utf-8"))


def sync_release_choices(addons=None, workflow=None, check=False):
    workflow = workflow or ROOT / ".github/workflows/next-release.yml"
    text = workflow.read_text(encoding="utf-8")
    choices = "".join(f"          - {a['name']}\n" for a in (registry() if addons is None else addons))
    pattern = r"(?m)(        # BEGIN ADDON CHOICES\n).*?(        # END ADDON CHOICES)"
    updated, count = re.subn(pattern, lambda match: match[1] + choices + match[2], text, flags=re.S)
    if count != 1:
        raise ValueError("Missing generated addon choice markers")
    if check and text != updated:
        raise ValueError("Addon dropdown is stale; run python .github/ci/next_release.py sync")
    if not check:
        workflow.write_text(updated, encoding="utf-8")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def tracked():
    return [p for p in git("ls-files", "-z").split("\0") if p]


def validate(addons, files):
    for addon in addons:
        root = inside(ROOT, addon["path"])
        manifest = inside(root, addon["manifest"])
        if not manifest.is_file():
            raise ValueError(f"Missing manifest: {manifest}")
        if not re.search(r"^## Version:\s*\S+", manifest.read_text(encoding="utf-8-sig"), re.M):
            raise ValueError(f"Missing version in {manifest}")
        requirements = (addon.get("tests") or {}).get("requirements")
        if requirements and not inside(root, requirements).is_file():
            raise ValueError(f"Missing requirements: {requirements}")
    for path in files:
        if path.endswith(".toc") and not any(path.startswith(a["path"] + "/") for a in addons):
            raise ValueError(f"Unregistered addon manifest: {path}; run addons.py register")


def select(addons, changed, previous=None):
    shared = any(p.startswith(".github/") for p in changed)
    old = {a["name"]: a for a in previous or []}
    return [a for a in addons if shared
            or any(p == a["path"] or p.startswith(a["path"] + "/") for p in changed)
            or ("addons.yml" in changed and old.get(a["name"]) != a)]


def plan():
    addons = registry()
    validate(addons, tracked())
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    if "pull_request" in event:
        base, head = event["pull_request"]["base"]["sha"], event["pull_request"]["head"]["sha"]
    elif os.environ.get("GITHUB_EVENT_NAME") == "push" and event.get("before", "0" * 40) != "0" * 40:
        base, head = event["before"], event["after"]
    else:
        base = head = None
    if base:
        # SHAs come from GitHub's event, never from PR titles or branch names.
        if not all(re.fullmatch(r"[0-9a-f]{40}", ref) for ref in (base, head)):
            raise ValueError("Invalid event commit SHA")
        refs = [f"{base}...{head}"] if "pull_request" in event else [base, head]
        changed = [p for p in git("diff", "--no-renames", "--name-only", "-z", *refs).split("\0") if p]
        try:
            previous_text = git("show", f"{base}:addons.yml")
        except subprocess.CalledProcessError:
            previous = []
        else:
            previous = parse_config(previous_text)
        selected = select(addons, changed, previous)
    else:
        selected = addons
    matrix = {"include": [{"addon": a["name"]} for a in selected]}
    print(json.dumps({"selected": [a["name"] for a in selected], "matrix": matrix}))
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(f"matrix={json.dumps(matrix, separators=(',', ':'))}\n")
        output.write(f"has_addons={'true' if selected else 'false'}\n")


def register(path, status):
    addons = registry()
    root = inside(ROOT, path)
    manifests = sorted(root.glob("*.toc"))
    preferred = root / f"{root.name}.toc"
    manifest = preferred if preferred in manifests else manifests[0] if len(manifests) == 1 else None
    if manifest is None:
        raise ValueError("Specify a directory containing one unambiguous .toc manifest")
    entry = {"name": root.name, "path": path, "manifest": manifest.name, "status": status}
    if (root / "tests/run.py").is_file():
        entry["tests"] = {"command": ["python", "tests/run.py"]}
        if (root / "tests/requirements.txt").is_file():
            entry["tests"]["requirements"] = "tests/requirements.txt"
    data = {"schema": 1, "addons": addons + [entry]}
    encoded = yaml.safe_dump(data, sort_keys=False, allow_unicode=True)
    parse_config(encoded)
    CONFIG.write_text(encoded, encoding="utf-8")
    workflow = ROOT / ".github/workflows/next-release.yml"
    if workflow.is_file():
        sync_release_choices(data["addons"], workflow)
    print(f"Registered {entry['name']}; review addons.yml before committing")


def run_tests(addon):
    tests = addon.get("tests")
    if not tests:
        print(f"{addon['name']}: no tests declared ({addon['status']}); security checks still run")
        return
    root = inside(ROOT, addon["path"])
    if tests.get("requirements"):
        subprocess.run([sys.executable, "-m", "pip", "install", "--only-binary=:all:", "-r", str(inside(root, tests["requirements"]))], check=True)
    command = list(tests["command"])
    if command[0] == "python":
        command[0] = sys.executable
    subprocess.run(command, cwd=root, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["plan", "register", "test", "audit"])
    parser.add_argument("addon", nargs="?")
    parser.add_argument("--status", choices=sorted(STATUSES), default="development")
    args = parser.parse_args()
    if args.action == "plan":
        plan()
    elif args.action == "register":
        register(args.addon, args.status)
    else:
        addon = next((a for a in registry() if a["name"] == args.addon), None)
        if addon is None:
            raise ValueError("Unknown addon identifier")
        if args.action == "test":
            run_tests(addon)
        else:
            requirements = (addon.get("tests") or {}).get("requirements")
            if requirements:
                subprocess.run([sys.executable, "-m", "pip_audit", "--strict", "--progress-spinner", "off", "-r", str(inside(ROOT / addon["path"], requirements))], check=True)
            else:
                print("No Python test dependencies declared; Lua API policy still runs")


if __name__ == "__main__":
    main()
