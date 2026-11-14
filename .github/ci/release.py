"""Build one registered addon and publish it through the CurseForge Upload API."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile

from addons import ROOT, git, inside, registry

CURSEFORGE = "https://wow.curseforge.com"
TAG = re.compile(r"([A-Za-z][A-Za-z0-9_-]*)/v([0-9]+\.[0-9]+\.[0-9]+(?:-(?:alpha|beta|rc)\.[0-9]+)?)")


def target(tag, addons=None):
    match = TAG.fullmatch(tag) if isinstance(tag, str) else None
    if not match:
        raise ValueError("Use an addon-specific tag such as CompactAddonButtons/v1.2.8")
    addon = next((a for a in (registry() if addons is None else addons) if a["name"] == match[1]), None)
    if not addon or not addon.get("release"):
        raise ValueError("Tag does not identify a release-enabled addon")
    return addon, match[2]


def channel(addon, version, prerelease=False):
    if "-alpha." in version:
        return "alpha"
    if "-beta." in version or "-rc." in version or prerelease:
        return "beta"
    return {"release": "release", "beta": "beta", "development": "alpha", "experiment": "alpha"}[addon["status"]]


def toc_version(addon):
    text = inside(ROOT / addon["path"], addon["manifest"]).read_text(encoding="utf-8-sig")
    matches = re.findall(r"^## Version:\s*(\S+)\s*$", text, re.M)
    if len(matches) != 1:
        raise ValueError("Manifest must declare exactly one version")
    return matches[0]


def package(addon, version, output):
    if toc_version(addon) != version:
        raise ValueError("Tag version does not match ## Version in the addon's .toc")
    root = inside(ROOT, addon["path"])
    files = {}
    for pattern in addon["release"]["files"]:
        matched = [p for p in root.glob(pattern) if p.is_file()]
        if not matched:
            raise ValueError(f"Release pattern matched no files: {pattern}")
        for path in matched:
            relative = path.relative_to(root)
            if path.is_symlink() or any(part.startswith(".") or part in {"tests", "node_modules", "__pycache__"} for part in relative.parts):
                raise ValueError(f"Development files/symlinks cannot be packaged: {relative}")
            safe = inside(root, relative.as_posix())
            files[relative.as_posix()] = safe.read_bytes()
    if addon["manifest"] not in files:
        raise ValueError("The configured manifest is missing from the ZIP")
    for entry in files[addon["manifest"]].decode("utf-8-sig").splitlines():
        entry = entry.strip()
        if entry and not entry.startswith("#") and entry not in files:
            raise ValueError(f"Manifest dependency is missing from the ZIP: {entry}")
    license_file = ROOT / "LICENSE"
    if license_file.is_file():
        files.setdefault("LICENSE", license_file.read_bytes())
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"{addon['name']}-{version}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for relative, content in sorted(files.items()):
            entry = zipfile.ZipInfo(f"{root.name}/{relative}", date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            bundle.writestr(entry, content, compresslevel=9)
    return archive


def prepare(tag, output, check_git=True):
    addon, version = target(tag)
    if check_git:
        # Release only commits already merged into main, and never a different checkout.
        commit = git("rev-parse", f"refs/tags/{tag}^{{commit}}").strip()
        if commit != git("rev-parse", "HEAD").strip():
            raise ValueError("Checkout does not match the requested tag")
        subprocess.run(["git", "merge-base", "--is-ancestor", commit, "origin/main"], cwd=ROOT, check=True)
    else:
        commit = "local-preview"
    archive = package(addon, version, output)
    metadata = {"addon": addon["name"], "version": version, "tag": tag, "commit": commit,
                "archive": archive.name, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
    (output / "release.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata))
    return metadata


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Refusing an API redirect; credentials must stay on the configured host")


def request_json(url, token, header, method="GET", payload=None, content_type="application/json"):
    if header == "X-Api-Token" and urllib.parse.urlsplit(url).netloc != "wow.curseforge.com":
        raise ValueError("Invalid CurseForge API host")
    if header == "Authorization" and urllib.parse.urlsplit(url).netloc not in {"api.github.com", "uploads.github.com"}:
        raise ValueError("Invalid GitHub API host")
    data = json.dumps(payload).encode() if payload is not None and not isinstance(payload, bytes) else payload
    req = urllib.request.Request(url, data=data, method=method, headers={
        header: token, "Content-Type": content_type, "Accept": "application/json", "User-Agent": "wow-forever-addons-release"})
    with urllib.request.build_opener(NoRedirect()).open(req, timeout=120) as response:
        body = response.read()
        return json.loads(body) if body else None


def resolve_versions(rows, config):
    result = []
    for name in config["game_versions"]:
        matches = [row for row in rows if row.get("name") == name and row.get("gameVersionTypeID") == config["game_version_type_id"]]
        if len(matches) != 1 or type(matches[0].get("id")) is not int or matches[0]["id"] <= 0:
            raise ValueError(f"No unambiguous CurseForge version for type {config['game_version_type_id']} / {name}; refusing a flavor fallback")
        result.append(matches[0]["id"])
    return result


def multipart(metadata, archive):
    boundary = "cab-release-" + uuid.uuid4().hex
    prefix = f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json\r\n\r\n"
    file_header = f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{archive.name}\"\r\nContent-Type: application/zip\r\n\r\n"
    return prefix.encode() + json.dumps(metadata).encode() + file_header.encode() + archive.read_bytes() + f"\r\n--{boundary}--\r\n".encode(), f"multipart/form-data; boundary={boundary}"


def find_release(github, tag):
    try:
        return github("/releases/tags/" + urllib.parse.quote(tag, safe=""))
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    # The tag endpoint may omit drafts. Authenticated listing includes them.
    page = 1
    while True:
        batch = github(f"/releases?per_page=100&page={page}")
        match = next((item for item in batch if item["tag_name"] == tag), None)
        if match or len(batch) < 100:
            return match
        page += 1


def api_error_message(error):
    endpoint = urllib.parse.urlsplit(error.url)
    message = f"Release API request failed: {endpoint.netloc}{endpoint.path} returned HTTP {error.code}"
    try:
        body = json.loads(error.read(8192))
        details = {key: body[key] for key in ("message", "error", "errors") if key in body} if isinstance(body, dict) else {}
        if details:
            message += ": " + json.dumps(details, ensure_ascii=True)
    except (ValueError, TypeError, OSError):
        pass
    for name in ("GITHUB_TOKEN", "CURSE_FORGE_DEPLOYMENT_TOKEN"):
        secret = os.environ.get(name)
        if secret:
            message = message.replace(secret, "[redacted]")
    return message[:2000] + "; inspect release assets before retrying an upload"


def publish(output):
    info = json.loads((output / "release.json").read_text(encoding="utf-8"))
    addon, version = target(info["tag"])
    if (info["addon"], info["version"]) != (addon["name"], version):
        raise ValueError("Artifact does not match its release tag")
    archive = inside(output, info["archive"])
    if archive.name != f"{addon['name']}-{version}.zip" or hashlib.sha256(archive.read_bytes()).hexdigest() != info["sha256"]:
        raise ValueError("Release artifact hash/name mismatch")
    commit = git("rev-parse", f"refs/tags/{info['tag']}^{{commit}}").strip()
    if commit != info["commit"]:
        raise ValueError("Tag moved after packaging")
    subprocess.run(["git", "merge-base", "--is-ancestor", commit, "origin/main"], cwd=ROOT, check=True)
    repo = os.environ["GITHUB_REPOSITORY"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError("Invalid repository")
    github_token = "Bearer " + os.environ["GITHUB_TOKEN"]
    cf_token = os.environ["CURSE_FORGE_DEPLOYMENT_TOKEN"]
    if not cf_token:
        raise ValueError("Missing CURSE_FORGE_DEPLOYMENT_TOKEN Actions secret")
    api = f"https://api.github.com/repos/{repo}"

    def github(path, method="GET", payload=None):
        return request_json(api + path, github_token, "Authorization", method, payload)

    release = find_release(github, info["tag"])
    if release is None:
        release = github("/releases", "POST", {"tag_name": info["tag"], "name": f"{addon['name']} {version}",
            "body": f"Release of {addon['name']} {version}.", "draft": True,
            "prerelease": channel(addon, version) != "release"})
    assets = []
    page = 1
    while True:
        batch = github(f"/releases/{release['id']}/assets?per_page=100&page={page}")
        assets.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    cf = addon["release"]["curseforge"]
    receipt_name = f"curseforge-{cf['project_id']}-{info['sha256']}.json"
    pending_name = f"curseforge-pending-{cf['project_id']}.json"
    if any(a["name"] == receipt_name for a in assets):
        pending = next((a for a in assets if a["name"] == pending_name), None)
        if pending and not release.get("immutable"):
            github(f"/releases/assets/{pending['id']}", "DELETE")
        if release.get("draft"):
            github(f"/releases/{release['id']}", "PATCH", {"draft": False})
        print("This exact archive already has a CurseForge upload receipt; skipping")
        return
    if any(a["name"] == pending_name for a in assets):
        raise ValueError("A previous upload has an uncertain outcome. Inspect CurseForge and the pending receipt before retrying; no duplicate POST will be sent")
    if release.get("immutable"):
        raise ValueError("GitHub Release is already immutable and has no CurseForge receipt. Assets cannot be added; use a new addon version and keep its release as a draft until deployment finishes. No CurseForge upload was sent")

    def asset(name, content, content_type):
        return request_json(f"https://uploads.github.com/repos/{repo}/releases/{release['id']}/assets?name=" + urllib.parse.quote(name, safe=""),
                            github_token, "Authorization", "POST", content, content_type)

    existing_zip = next((a for a in assets if a["name"] == archive.name), None)
    if existing_zip:
        if existing_zip.get("digest") != "sha256:" + info["sha256"]:
            raise ValueError("Existing GitHub ZIP has a different or unavailable digest; refusing to overwrite")
    else:
        asset(archive.name, archive.read_bytes(), "application/zip")
    rows = request_json(CURSEFORGE + "/api/game/wow/versions", cf_token, "X-Api-Token")
    metadata = {"displayName": f"{addon['name']} {version}", "gameVersions": resolve_versions(rows, cf),
                "releaseType": channel(addon, version, release.get("prerelease", False)),
                "changelogType": "markdown", "changelog": release.get("body") or f"Release {version}"}
    pending = asset(pending_name, json.dumps({**info, "project_id": cf["project_id"]}).encode(), "application/json")
    body, content_type = multipart(metadata, archive)
    # Never automatically retry this non-idempotent POST: a timeout may follow success.
    result = request_json(f"{CURSEFORGE}/api/projects/{cf['project_id']}/upload-file", cf_token,
                          "X-Api-Token", "POST", body, content_type)
    if not isinstance(result, dict) or type(result.get("id")) is not int or result["id"] <= 0:
        raise ValueError("CurseForge did not return a file ID; keep the pending receipt and investigate")
    asset(receipt_name, json.dumps({**info, "project_id": cf["project_id"], "file_id": result["id"]}).encode(), "application/json")
    github(f"/releases/assets/{pending['id']}", "DELETE")
    if release.get("draft"):
        github(f"/releases/{release['id']}", "PATCH", {"draft": False})
    print(f"CurseForge accepted file {result['id']} for project {cf['project_id']}; approval may still be pending")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["target", "prepare", "publish", "preview"])
    parser.add_argument("--tag", default=os.environ.get("RELEASE_TAG"))
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    if args.action == "target":
        addon, version = target(args.tag)
        if toc_version(addon) != version:
            raise ValueError("Tag version must match the manifest")
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.write(f"addon={addon['name']}\n")
    elif args.action in {"prepare", "preview"}:
        prepare(args.tag, args.output, check_git=args.action != "preview")
    else:
        try:
            publish(args.output)
        except urllib.error.HTTPError as error:
            raise SystemExit(api_error_message(error)) from None


if __name__ == "__main__":
    main()
