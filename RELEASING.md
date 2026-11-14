# Per-addon GitHub and CurseForge releases

Each addon has its own version in `## Version` of its `.toc` and its own tag:

```text
CompactAddonButtons/v1.2.8
AnotherAddon/v2.0.0
```

There is no repository-wide version. A release selects exactly one registered
addon; other addons are neither tested nor uploaded by the release workflow.
Tag versions must exactly match the selected manifest. Tags must point to commits
already merged into `main`. Do not move or reuse release tags.

## Configuration

The addon's `release` entry in `addons.yml` declares the package file allowlist,
CurseForge project ID, game flavor type ID, and supported game version names.
The current CompactAddonButtons configuration uses project **1804859**, Forever
type **88568**, and **1.60.1** (the game version corresponding to Interface 16001).

At upload time the workflow queries the Upload API's `/api/game/wow/versions`
catalog and resolves each exact `(gameVersionTypeID, name)` pair to its numeric
file-version ID. It never substitutes Retail, Classic, a newer version, or a nearby
version if the requested Forever version cannot be found. Version type 88568 is
also used for Forever by the upstream [WoW packager](https://github.com/BigWigsMods/packager/blob/master/release.sh).

New addons reuse the same workflow. After registration, add their own `release`
configuration and CurseForge project ID; review the supported game versions and
package patterns for that addon. Unconfigured addons cannot be released accidentally.
The `files` list uses Python path glob patterns relative to the addon directory.
Only matched files are included, plus the repository license. Test directories,
hidden files, node_modules, and symbolic links are rejected. Every Lua file listed
by the manifest must be present in the ZIP. The ZIP has a single installable root
folder matching the addon's directory name; for CompactAddonButtons this includes
`Media/Icon.tga` and excludes the development README, PNG preview, and tests.

## One-time secret

In repository Actions secrets, set **CURSE_FORGE_DEPLOYMENT_TOKEN** to an author
Upload API token that can upload to all configured projects. Do not use the separate
CurseForge for Studios read API key. The secret is supplied only to the upload step,
in the `X-Api-Token` header, never in URLs, logs, ZIPs, or PR checks. The project must
already exist on CurseForge and the token owner must have access to it.

## Publish

1. Update the selected addon's `.toc` version and merge the change into `main`.
2. Either publish a GitHub Release using a matching addon tag, or push that tag:

   ```sh
   git tag CompactAddonButtons/v1.2.8
   git push origin CompactAddonButtons/v1.2.8
   ```

3. The **Release addon** workflow validates the tag and its `main` ancestry, tests
   and security-checks only that addon, and builds a deterministic ZIP. A separate
   publishing job downloads that run's immutable artifact by ID, verifies its
   hash/tag/commit, and uses deployment code/configuration checked out from `main`.
4. The job attaches the ZIP to the GitHub Release (creating the Release if the tag
   was pushed directly) and uploads the same ZIP to the configured CurseForge project.
   GitHub Release notes become the CurseForge changelog. Direct tag publication
   creates a short default changelog; publish a GitHub Release with notes when you
   want a detailed changelog from the start.

Both tag and Release events are supported. Runs for the same tag are serialized,
and successful uploads record a JSON receipt with the CurseForge file ID and ZIP
SHA-256 in the GitHub Release. Subsequent events or reruns skip that exact upload.
An automatically created Release does not need to trigger another workflow.

The registry status maps to `release`, `beta`, or `alpha` (`development` and
`experiment` map to `alpha`). Tag suffixes `-alpha.1`, `-beta.1`, and `-rc.1` select
alpha/beta explicitly, and a GitHub prerelease is uploaded as beta unless the tag
already selects alpha. The manifest must contain the same suffix as the tag.

## Preview without publication

Run **Release addon** manually with a prospective tag matching the version in
`main`, such as `CompactAddonButtons/v1.2.8`. The tag does not need to exist:
`workflow_dispatch` checks out `main`, validates, tests, and builds, and **never
publishes** or receives the CurseForge secret. Download the resulting
`release-package` artifact to inspect the ZIP before creating a real tag.

For a local package preview without requiring a Git tag:

```sh
python -m pip install -r .github/ci/requirements.txt
python .github/ci/release.py preview --tag CompactAddonButtons/v1.2.8 --output .tools/release-preview
```

## Failures and moderation

A `curseforge-pending-PROJECT.json` GitHub Release asset is written before sending
the non-idempotent upload request. If a timeout, crash, or malformed response leaves
that marker without a success receipt, reruns refuse to send another POST. Inspect
the CurseForge project first: if the file was accepted, retain its ID and reconcile
the receipt; only remove the pending marker after confirming no file was created.
This deliberately trades automatic retry for avoiding duplicate public uploads.
Do not delete success receipts to force a release; publish a new version instead.

Existing GitHub ZIP assets must have the same SHA-256 digest; they are never silently
overwritten. A moved tag, altered artifact, version mismatch, missing token,
unsupported game version, or unknown project configuration fails the job.

An accepted upload returns a CurseForge file ID. CurseForge moderation/approval may
still be pending; successful upload is not a guarantee of immediate public visibility.
The upload code uses the documented [Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api),
not the read-oriented [Get Files API](https://docs.curseforge.com/rest-api/).
