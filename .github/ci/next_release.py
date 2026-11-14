"""Prepare a version-only PR, then create its tag/release after a human merges it."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.parse

from addons import registry, sync_release_choices
from release import channel, request_json

VERSION_LINE = re.compile(r"(?m)^(## Version:[ \t]*)([^\r\n]+)(\r?)$")


def next_version(current, bump):
    if not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", current):
        raise ValueError("Automatic bumps require a stable major.minor.patch version")
    major, minor, patch = map(int, current.split("."))
    if bump == "patch":
        patch += 1
    elif bump == "minor":
        minor, patch = minor + 1, 0
    elif bump == "major":
        major, minor, patch = major + 1, 0, 0
    else:
        raise ValueError("Choose patch, minor, or major")
    return f"{major}.{minor}.{patch}"


def version_of(text):
    matches = list(VERSION_LINE.finditer(text))
    if len(matches) != 1:
        raise ValueError("Expected exactly one ## Version line")
    return matches[0][2].strip()


def bumped_manifest(text, previous, version):
    if version_of(text) != previous:
        raise ValueError("Manifest changed since the release request was prepared")
    return VERSION_LINE.sub(lambda m: m[1] + version + m[3], text)


def blob_sha(text):
    data = text.encode("utf-8")
    return hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()


class GitHub:
    def __init__(self):
        self.repo = os.environ["GITHUB_REPOSITORY"]
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", self.repo):
            raise ValueError("Invalid repository")
        self.token = "Bearer " + os.environ["GITHUB_TOKEN"]

    def call(self, path, method="GET", payload=None):
        return request_json(f"https://api.github.com/repos/{self.repo}" + path, self.token, "Authorization", method, payload)

    def optional(self, path):
        try:
            return self.call(path)
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
            return None

    def text(self, path, ref, optional=False):
        url = "/contents/" + urllib.parse.quote(path, safe="/") + "?ref=" + urllib.parse.quote(ref, safe="")
        data = self.optional(url) if optional else self.call(url)
        return base64.b64decode(data["content"]).decode("utf-8") if data else None


def release_addon(name):
    addon = next((a for a in registry() if a["name"] == name and a.get("release")), None)
    if not addon:
        raise ValueError("Select a registered addon with release/CurseForge configuration")
    return addon


def request_files(api, addon, intent):
    manifest_path = addon["path"] + "/" + addon["manifest"]
    original = api.text(manifest_path, intent["base_sha"])
    files = {manifest_path: bumped_manifest(original, intent["previous_version"], intent["version"])}
    readme_path = addon["path"] + "/README.md"
    readme = api.text(readme_path, intent["base_sha"], optional=True)
    old = f"Version **{intent['previous_version']}**"
    if readme and old in readme:
        files[readme_path] = readme.replace(old, f"Version **{intent['version']}**")
    files[f"release-requests/{addon['name']}.json"] = json.dumps(intent, indent=2, ensure_ascii=False) + "\n"
    return files


def create_request(api, name, bump, notes=""):
    addon = release_addon(name)
    base = api.call("/branches/main")["commit"]
    current = version_of(api.text(addon["path"] + "/" + addon["manifest"], base["sha"]))
    version = next_version(current, bump)
    branch = f"codex/release-{name}-{version}"
    if not isinstance(notes, str) or len(notes) > 10000:
        raise ValueError("Release notes must contain at most 10000 characters")
    intent = {"addon": name, "previous_version": current, "version": version, "bump": bump,
              "tag": f"{name}/v{version}", "base_sha": base["sha"], "notes": notes}
    existing = api.optional("/git/ref/heads/" + branch)
    if existing:
        prs = api.call("/pulls?state=all&head=" + urllib.parse.quote(api.repo.split("/")[0] + ":" + branch, safe=""))
        if len(prs) == 1 and prs[0]["state"] == "open":
            print(f"Release request already exists: {prs[0]['html_url']}")
            return prs[0]
        if prs:
            raise ValueError("Release branch has closed or conflicting PRs; refusing to reopen a cancelled release")
        # A previous run may have created the branch before PR creation was denied.
        saved = json.loads(api.text(f"release-requests/{name}.json", existing["object"]["sha"]))
        if (set(saved) != set(intent) or not re.fullmatch(r"[0-9a-f]{40}", saved.get("base_sha", ""))
                or any(saved[key] != value for key, value in intent.items() if key != "base_sha")):
            raise ValueError("Existing release branch describes a different request; refusing to overwrite it")
        expected = request_files(api, addon, saved)
        comparison = api.call(f"/compare/{saved['base_sha']}...{existing['object']['sha']}")
        if {f["filename"]: f["sha"] for f in comparison["files"]} != {p: blob_sha(c) for p, c in expected.items()}:
            raise ValueError("Existing release branch was modified; refusing to resume it")
        intent = saved
        print(f"Resuming validated release branch: {branch}")
    else:
        files = request_files(api, addon, intent)
        tree = api.call("/git/trees", "POST", {"base_tree": base["commit"]["tree"]["sha"], "tree": [
            {"path": path, "mode": "100644", "type": "blob", "content": content} for path, content in files.items()]})
        commit = api.call("/git/commits", "POST", {"message": f"Release {name} {version}", "tree": tree["sha"], "parents": [base["sha"]]})
        api.call("/git/refs", "POST", {"ref": "refs/heads/" + branch, "sha": commit["sha"]})
    try:
        pr = api.call("/pulls", "POST", {"base": "main", "head": branch, "title": f"Release {name} {version}",
            "body": f"Bump {name} from {current} to {version} ({bump}).\n\nAfter CI passes and this PR is merged, the release workflow creates `{intent['tag']}` and publishes to CurseForge.\n\n" + (notes or "No additional release notes.")})
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
        raise SystemExit(
            "GitHub denied PR creation (HTTP 403). In Settings > Actions > General > Workflow permissions, "
            "enable 'Allow GitHub Actions to create and approve pull requests' and Save. "
            "If an organization policy disables that setting, contact its administrator. "
            f"The branch {branch} has been preserved. Start a NEW 'Next addon version' run from main "
            f"with addon={name} and bump={bump} to resume it; no tag or release has been published."
        ) from None
    print(f"Prepared {current} -> {version}: {pr['html_url']}")
    return pr


def finalize(api, event):
    pr = api.call(f"/pulls/{int(event['number'])}")
    if not (pr.get("merged") and pr["user"]["login"] == "github-actions[bot]" and pr["base"]["ref"] == "main"
            and pr["head"]["repo"]["full_name"] == api.repo):
        raise ValueError("Only a merged, same-repository release PR created by Actions can be finalized")
    branch = re.fullmatch(r"codex/release-([A-Za-z][A-Za-z0-9_-]*)-([0-9]+\.[0-9]+\.[0-9]+)", pr["head"]["ref"])
    if not branch:
        raise ValueError("Not a generated release branch")
    addon = release_addon(branch[1])
    intent = json.loads(api.text(f"release-requests/{addon['name']}.json", pr["merge_commit_sha"]))
    if set(intent) != {"addon", "previous_version", "version", "bump", "tag", "base_sha", "notes"}:
        raise ValueError("Invalid release request")
    if (intent["addon"], intent["version"], intent["tag"]) != (branch[1], branch[2], f"{branch[1]}/v{branch[2]}"):
        raise ValueError("Release request does not match its PR branch")
    if not re.fullmatch(r"[0-9a-f]{40}", intent["base_sha"]) or next_version(intent["previous_version"], intent["bump"]) != intent["version"]:
        raise ValueError("Invalid release version transition")
    expected = request_files(api, addon, intent)
    comparison = api.call(f"/compare/{intent['base_sha']}...{pr['head']['sha']}")
    actual = {f["filename"]: f["sha"] for f in comparison["files"]}
    if actual != {path: blob_sha(content) for path, content in expected.items()}:
        raise ValueError("Release PR contains changes beyond the generated version bump")
    merged_version = version_of(api.text(addon["path"] + "/" + addon["manifest"], pr["merge_commit_sha"]))
    if merged_version != intent["version"]:
        raise ValueError("Merged manifest does not match the requested release")
    tag = intent["tag"]
    ref = api.optional("/git/ref/tags/" + tag)
    if ref:
        if ref["object"]["type"] != "commit" or ref["object"]["sha"] != pr["merge_commit_sha"]:
            raise ValueError("Release tag already points to a different commit")
    else:
        api.call("/git/refs", "POST", {"ref": "refs/tags/" + tag, "sha": pr["merge_commit_sha"]})
    if not api.optional("/releases/tags/" + urllib.parse.quote(tag, safe="")):
        api.call("/releases", "POST", {"tag_name": tag, "name": f"{addon['name']} {intent['version']}",
            "body": intent["notes"] or f"Release {addon['name']} {intent['version']}.",
            "prerelease": channel(addon, intent["version"]) != "release"})
    # Token-generated tag/release events do not start workflows; dispatch explicitly.
    api.call("/actions/workflows/release.yml/dispatches", "POST", {"ref": "main", "inputs": {"tag": tag, "publish": "true"}})
    print(f"Created {tag} and dispatched its release workflow")


if __name__ == "__main__":
    import sys
    if sys.argv[1] == "sync":
        sync_release_choices()
    elif sys.argv[1] == "request":
        create_request(GitHub(), os.environ["ADDON_INPUT"], os.environ["BUMP_INPUT"], os.environ.get("NOTES_INPUT", ""))
    elif sys.argv[1] == "finalize":
        finalize(GitHub(), json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8")))
    else:
        raise SystemExit("Choose sync, request, or finalize")
