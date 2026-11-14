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

## Choose the next version in Actions

Open **Actions → Next addon version → Run workflow** on `main`:

1. Select the addon from the dropdown.
2. Select `patch`, `minor`, or `major` (default: `patch`). From 1.2.8 these yield
   1.2.9, 1.3.0, and 2.0.0 respectively. Optional release notes become the changelog.
3. Run the workflow. It creates a PR that updates only the selected manifest's
   version, the README's matching version label if present, and a release request
   under `release-requests/`. It does not publish or change the game installation.
4. Review and merge that PR after CI passes. A second job checks that the bot PR
   contains exactly the generated files, creates the addon tag at its merge commit,
   creates a draft GitHub Release, and explicitly dispatches **Release addon** to publish.

If GitHub asks to **Approve workflows to run** on the generated PR, approve that
CI run before merging. Repository settings must permit Actions to create PRs:
**Settings → Actions → General → Workflow permissions → Allow GitHub Actions to
create and approve pull requests**. The automation creates PRs but never approves
or merges them. No additional personal access token is required.

If PR creation returns HTTP 403, the workflow may already have created its release
branch. Enable the setting above and start a **new** Next addon version run from
`main` with the same addon, bump, and notes. It validates and reuses the original
branch without rewriting it or bumping again. Re-running an old failed job uses
that job's older script revision, so prefer a new workflow run after updating the
automation. Modified branches or cancelled release PRs are never resumed silently.

Automatic increments accept stable `major.minor.patch` versions. For prerelease
suffixes or a custom version, use the manual version/tag process below. Repeating
the same selection while its release PR is open returns the existing PR.

Generated branches use `release/<AddonName>/<version>`, for example
`release/CompactAddonButtons/1.3.0`. Release commits and PR titles follow
Commitizen / Conventional Commits: `chore(CompactAddonButtons): release 1.3.0`.
Repository branch and commit conventions are recorded in `AGENTS.md` and `.cz.toml`.

GitHub's `choice` options are static YAML, so the list is generated from
`addons.yml`, not fetched dynamically by the web UI. The registration command
updates the choices automatically; after manually editing the registry, run:

```sh
python .github/ci/next_release.py sync
```

CI rejects a stale dropdown. Addons without release configuration can appear in
the registry list but cannot create a release request until configured.

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
2. Push the matching addon tag (or create a draft GitHub Release with notes, then
   run **Release addon** manually with that tag and **publish checked**):

   ```sh
   git tag CompactAddonButtons/v1.2.8
   git push origin CompactAddonButtons/v1.2.8
   ```

3. The **Release addon** workflow validates the tag and its `main` ancestry, tests
   and security-checks only that addon, and builds a deterministic ZIP. A separate
   publishing job downloads that run's immutable artifact by ID, verifies its
   hash/tag/commit, and uses deployment code/configuration checked out from `main`.
4. The job attaches the ZIP to the draft GitHub Release (creating a draft if the tag
   was pushed directly) and uploads the same ZIP to the configured CurseForge project.
   GitHub Release notes become the CurseForge changelog. Direct tag publication
   creates a short default changelog; create a draft GitHub Release with notes when you
   want a detailed changelog from the start.
5. After recording the CurseForge file ID and removing the pending marker, the job
   publishes the GitHub Release. All assets are attached before publication, so
   repositories with GitHub immutable releases enabled are supported.

Both tag and Release events are supported. Runs for the same tag are serialized,
and successful uploads record a JSON receipt with the CurseForge file ID and ZIP
SHA-256 in the GitHub Release. Subsequent events or reruns skip that exact upload.
An automatically created Release does not need to trigger another workflow.
An already published immutable Release without a success receipt cannot accept
assets and is rejected before any CurseForge upload. Do not publish the draft
manually while deployment is running. Use a new addon version if a previous
immutable Release was published before its ZIP and receipt were attached.

The registry status maps to `release`, `beta`, or `alpha` (`development` and
`experiment` map to `alpha`). Tag suffixes `-alpha.1`, `-beta.1`, and `-rc.1` select
alpha/beta explicitly, and a GitHub prerelease is uploaded as beta unless the tag
already selects alpha. The manifest must contain the same suffix as the tag.

## Preview without publication

Run **Release addon** manually with **publish unchecked** and a prospective tag matching the version in
`main`, such as `CompactAddonButtons/v1.2.8`. The tag does not need to exist:
this mode checks out `main`, validates, tests, and builds, and **never publishes**
or receives the CurseForge secret. Download the resulting
`release-package` artifact to inspect the ZIP before creating a real tag.

The optional **publish** checkbox is for explicitly publishing an existing tag.
The merged version-PR job uses this mode because GitHub does not trigger workflows
from token-created tag/Release events; `workflow_dispatch` is an exception. Leave
it unchecked when previewing a package.

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
If only the final GitHub publication failed, rerun the workflow: the existing
success receipt prevents a second CurseForge upload and the draft is published.
HTTP failures identify the API host/path and status. Remote response bodies are
never printed, because they could echo secrets or encoded credentials.

Existing GitHub ZIP assets must have the same SHA-256 digest; they are never silently
overwritten. A moved tag, altered artifact, version mismatch, missing token,
unsupported game version, or unknown project configuration fails the job.

An accepted upload returns a CurseForge file ID. CurseForge moderation/approval may
still be pending; successful upload is not a guarantee of immediate public visibility.
The upload code uses the documented [Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api),
not the read-oriented [Get Files API](https://docs.curseforge.com/rest-api/).

## Release security boundaries

The build job has read-only repository permissions and no CurseForge secret. It
runs addon tests and creates an archive from the configured runtime allowlist.
Publication uses a separate runner, downloads only that run's artifact by ID, and
executes deployment scripts checked out from `main`. The ZIP is uploaded as data;
addon code from it is never executed in the job that receives deployment secrets.
Manual publication must run from `main`.

Only the final upload step receives `CURSE_FORGE_DEPLOYMENT_TOKEN` and its GitHub
token as environment variables. Credentials are never command-line arguments or
URL parameters. Authenticated API requests require HTTPS, an exact approved host
for the credential header, and no redirects. Artifact metadata must use the exact
known schema and match the workflow's requested tag before any API request; no
extra artifact fields are copied into public upload receipts.

Privileged release jobs install only PyYAML from `deployment-requirements.txt`,
using a SHA-256-verified binary wheel. This lock targets CPython 3.12 on Linux
x86_64, matching the release runners. When updating it, obtain the wheel digest
from PyPI and validate with `pip download --require-hashes --only-binary=:all:` on
the target platform. Full CI audit/test dependencies remain in `requirements.txt`.
GitHub actions are pinned to full commit SHAs and checkout does not retain Git
credentials. Regression tests enforce these workflow boundaries.

A review on 2026-11-14 covered nine executed jobs across the available release and
version-request runs, plus the public 1.2.10 ZIP and receipt. Token environment
values in those logs were masked; no recognizable unmasked GitHub/AWS/private-key
credential patterns were found. The ZIP contained 19 runtime/license files and
the receipt contained only release identifiers, hashes and the CurseForge file ID.
This review is scoped to those logs/assets and does not prove that every possible
secret is absent from all repository history or private artifacts.

Maintainers who can change `main` or workflow definitions remain trusted. Script
checks do not replace repository access control. For stronger deployment policy,
configure a protected GitHub Environment with restricted deployment refs and
store the CurseForge token there; this requires repository settings and moving
the secret, and is not enabled automatically by these workflows. Revoke tokens
shared outside the Actions secret store when the diagnostic session is finished.
