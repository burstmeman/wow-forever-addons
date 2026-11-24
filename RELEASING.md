# Per-addon GitHub and CurseForge releases

Each addon has its own version in `## Version` of its `.toc` and its own tag:

```text
CompactAddonButtons/v1.2.8
AnotherAddon/v2.0.0
```

There is no repository-wide version. A release selects exactly one registered
addon. The release workflow does not test or upload the others. The tag version
must match the selected manifest exactly. The tag must point at a commit already
on `main`. Do not move a release tag, and do not reuse one.

## Choose the next version in Actions

Open Actions, then Next addon version, then Run workflow, on `main`:

1. Select the addon from the dropdown.
2. Select `patch`, `minor`, or `major`. The default is `patch`. From 1.2.8 these
   yield 1.2.9, 1.3.0, and 2.0.0. Optional release notes become the changelog.
3. Run the workflow. It opens a pull request that changes only the selected
   manifest's version and a release request under `release-requests/`. It does
   not publish, and it does not change the game installation.
4. Review that pull request and merge it after CI passes. A second job checks
   that the bot pull request contains exactly the generated files, creates the
   addon tag at the merge commit, creates a draft GitHub Release, and dispatches
   Release addon so the package is published.

If GitHub asks you to approve workflows before they run on the generated pull
request, approve that CI run before merging. Repository settings must let
Actions create pull requests: Settings, Actions, General, Workflow permissions,
then "Allow GitHub Actions to create and approve pull requests". The automation
creates pull requests. It does not approve them and it does not merge them. No
extra personal access token is required.

If pull request creation returns HTTP 403, the workflow may already have created
its release branch. Turn on the setting above and start a new Next addon version
run from `main` with the same addon, bump, and notes. That run checks the
original branch and reuses it. It does not rewrite the branch and it does not
bump the version again. Re-running an old failed job uses that job's older
script, so after you change the automation, start a new workflow run. A modified
branch, and a cancelled release pull request, are left alone.

Automatic increments accept a stable `major.minor.patch` version. For a
prerelease suffix or a custom version, use the manual version and tag steps
below. Asking for the same selection again while its release pull request is
open returns that pull request.

Generated branches use `release/<AddonName>/<version>`, for example
`release/CompactAddonButtons/1.3.0`. Release commits and pull request titles
follow Commitizen / Conventional Commits:
`chore(CompactAddonButtons): release 1.3.0`. Branch and commit conventions are
in `AGENTS.md` and `.cz.toml`.

GitHub `choice` options are static YAML. The list is generated from
`addons.yml`. The web UI does not fetch it. Registration updates the choices.
After you edit the registry by hand, run:

```sh
python .github/ci/next_release.py sync
```

CI rejects a stale dropdown. An addon with no release configuration can appear
in the registry and still cannot create a release request until it is configured.

## Configuration

The addon's `release` entry in `addons.yml` declares the package file allowlist,
the CurseForge project ID, the game flavor type ID, and the supported game
version names. CompactAddonButtons uses project 1804859, Forever type 88568,
and 1.60.1, the game version for Interface 16001.

At upload time the workflow queries the Upload API catalog at
`/api/game/wow/versions` and resolves each exact `(gameVersionTypeID, name)`
pair to its numeric file-version ID. If the requested Forever version is
missing, it does not substitute Retail, Classic, a newer version, or a nearby
version. Version type 88568 is also the Forever type used by the upstream
[WoW packager](https://github.com/BigWigsMods/packager/blob/master/release.sh).

A new addon uses the same workflow. After registration, add its own `release`
configuration and CurseForge project ID, and review the game versions and
package patterns for that addon. An addon with no release configuration cannot
be released by accident. The `files` list uses Python path globs relative to
the addon directory. The package includes matched runtime files and the
repository license. Test directories, hidden files, `node_modules`, symbolic
links, and non-runtime file types are rejected. A code glob is allowed, but
every packaged Lua or XML file must be named by the selected manifest, and
every manifest entry must be present. An extra manifest fails the build. A
media or font asset needs an exact path, not a glob, so a preview or a source
image is not packed just because it sits nearby. The ZIP has one installable
root folder, named like the addon directory. CompactAddonButtons includes its
manifest, 16 Lua files, two runtime TGA textures, and LICENSE. README files,
preview PNGs, tests, and CI tooling stay out.

## One-time secret

In repository Actions secrets, set `CURSE_FORGE_DEPLOYMENT_TOKEN` to an author
Upload API token that can upload to every configured project. Do not use the
CurseForge for Studios read API key. The secret is given only to the upload
step, in the `X-Api-Token` header. It is not placed in URLs, logs, ZIPs, or
pull request checks. The project must already exist on CurseForge, and the
token owner must have access to it.

## Publish

1. Update the selected addon's `.toc` version and merge that change into `main`.
2. Push the matching addon tag, or create a draft GitHub Release with notes and
   then run Release addon by hand with that tag and publish checked:

   ```sh
   git tag CompactAddonButtons/v1.2.8
   git push origin CompactAddonButtons/v1.2.8
   ```

3. The Release addon workflow checks the tag and that it descends from `main`,
   tests and security-checks only that addon, and builds a deterministic ZIP. A
   separate publishing job downloads that run's artifact by ID, checks its
   hash, tag, and commit, and uses deployment code and configuration checked
   out from `main`. Before the artifact is uploaded, the build checks its exact
   file inventory and contents, extracts the runtime into a temporary directory,
   and tests it.
4. The job attaches the ZIP to the draft GitHub Release. If the tag was pushed
   directly, it creates that draft. It uploads the same ZIP to the configured
   CurseForge project. GitHub Release notes become the CurseForge changelog. A
   direct tag publish writes a short default changelog. Create a draft GitHub
   Release with notes first when you want a longer changelog from the start.
5. After it records the CurseForge file ID and removes the pending marker, the
   job publishes the GitHub Release. Every asset is attached before publication,
   which is what repositories with immutable GitHub releases need.

Tag events and Release events both work. Runs for the same tag are serialized.
A successful upload stores a JSON receipt on the GitHub Release, with the
CurseForge file ID and the ZIP SHA-256. A later event or a rerun skips that
same upload. A Release the workflow created does not need to start another
workflow. An immutable Release that is already public, and has no success
receipt, cannot take new assets. That case is rejected before any CurseForge
upload. Do not publish the draft yourself while deployment is running. If an
immutable Release went public before its ZIP and receipt were attached, publish
a new addon version.

Registry status maps to `release`, `beta`, or `alpha`. `development` and
`experiment` map to `alpha`. Tag suffixes `-alpha.1`, `-beta.1`, and `-rc.1`
select alpha or beta explicitly. A GitHub prerelease is uploaded as beta unless
the tag already selects alpha. The manifest must carry the same suffix as the
tag.

## Preview without publication

Run Release addon by hand with publish unchecked and a prospective tag that
matches the version on `main`, such as `CompactAddonButtons/v1.2.8`. The tag
does not have to exist. This mode checks out `main`, validates, tests, and
builds. It does not publish, and it does not receive the CurseForge secret.
Download the `release-package` artifact and inspect the ZIP before you create
a real tag.

The publish checkbox is for publishing a tag that already exists. The job that
runs after the version pull request merges uses the unchecked mode, because
GitHub does not start workflows from a tag or Release created with the
workflow's token. `workflow_dispatch` is the exception. Leave publish unchecked
when you are only previewing a package.

For a local package preview, no Git tag is required:

```sh
python -m pip install -r .github/ci/requirements.txt
python .github/ci/lua_minify.py setup
python .github/ci/release.py preview --tag CompactAddonButtons/v1.2.8 --output .tools/release-preview
python .github/ci/release.py verify --output .tools/release-preview
```

Install the addon's test requirements before you run `verify` locally. Pull
request CI also runs `release.py check --addon NAME` for selected addons that
have a release configuration. That builds and checks a temporary package with
no tag and no deployment credentials.

## Minified runtime and package checks

Release packaging uses upstream [LuaSrcDiet 1.0.0-2](https://luarocks.org/modules/jirutka/luasrcdiet/1.0.0-2)
to strip comments and unnecessary whitespace outside string literals. The
source package is pinned by SHA-256 in `lua_minify.py`. Setup checks that pin
before it loads any module. Only the required modules and the upstream license
files are unpacked into `.tools/luasrcdiet/`, which is gitignored. This
repository does not keep its own Lua parser or minifier.

CI installs native Lua 5.1 and prepares the pinned package before tooling tests
or addon packaging. The publisher job does not download the minifier and does
not run it. For a local preview, install Lua 5.1 and run the setup command
above. Windows can use the existing Lupa 2.8 Lua 5.1 test runtime. There is no
path that skips the check.

The source-token check and the Lua 5.1 binary equivalence check both have to
pass before the result is accepted. The selected options keep names, operators,
string bytes, localization, and manifest load order. The minifier does not
rename globals or locals, does not obfuscate code, and does not emit bytecode.
Repository sources stay readable. Line numbers in a packaged traceback can
differ from the repository, because removed comments and whitespace change the
line count.

Pull request CI and the release build both inspect the ZIP before they run the
packaged code. An unexpected path, a missing path, a duplicate path, altered
contents, or a hash mismatch fails the check. The test command runs from the
source checkout with `ADDON_RUNTIME_PATH` pointing at the extracted addon.
A release-enabled test harness must honor that variable when it loads runtime
files. Test code and fixtures stay in the checkout. CompactAddonButtons runs
all 16 Lua 5.1 scenarios against the extracted minified runtime and against
the regular source.

Install the attached `AddonName-version.zip`, or use the CurseForge file.
GitHub's automatic Source code ZIP and tar archives contain the repository,
including tests and documentation. They are not the installable package, and
they are not uploaded to CurseForge.

## Failures and moderation

A `curseforge-pending-PROJECT.json` asset is written to the GitHub Release
before the upload POST, which cannot be repeated safely. If a timeout, a crash,
or a malformed response leaves that marker and no success receipt, a rerun
will not send another POST. Look at the CurseForge project first. If the file
was accepted, keep its ID and reconcile the receipt. Remove the pending marker
only after you have confirmed that no file was created. The workflow skips
automatic retry so it does not publish the same file twice. Do not delete a
success receipt to force another release. Publish a new version. If only the
final GitHub publication failed, rerun the workflow: the existing receipt
blocks a second CurseForge upload, and the draft is published. An HTTP failure
names the API host, path, and status. Response bodies from the remote are not
printed, because they can echo a secret or an encoded credential.

An existing GitHub ZIP asset must have the same SHA-256. It is not replaced
quietly. A moved tag, an altered artifact, a version mismatch, a missing
token, an unsupported game version, or an unknown project configuration fails
the job.

An accepted upload returns a CurseForge file ID. CurseForge may still be
reviewing it, so the file might not be public yet. The upload code uses the
documented [Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api),
not the read-oriented [Get Files API](https://docs.curseforge.com/rest-api/).

## Release security boundaries

The build job has read-only repository permissions and no CurseForge secret. It
runs the addon tests and creates an archive from the configured runtime
allowlist. Publication uses a separate runner, downloads only that run's
artifact by ID, and runs deployment scripts checked out from `main`. The ZIP
is uploaded as data. Addon code from that ZIP is not executed in the job that
holds the deployment secrets. A manual publication must run from `main`.

Only the final upload step receives `CURSE_FORGE_DEPLOYMENT_TOKEN` and its
GitHub token as environment variables. Credentials are never command-line
arguments or URL parameters. An authenticated API request requires HTTPS, an
exact approved host for the credential header, and no redirects. Artifact
metadata must use the known schema and match the tag the workflow requested
before any API request. Extra artifact fields are not copied into public
upload receipts.

Privileged release jobs install only PyYAML from `deployment-requirements.txt`,
using a SHA-256-verified binary wheel. The lock targets CPython 3.12 on Linux
x86_64, the same platform as the release runners. When you update it, take the
wheel digest from PyPI and check it with
`pip download --require-hashes --only-binary=:all:` on that platform. The full
CI audit and test dependencies stay in `requirements.txt`. GitHub actions are
pinned to full commit SHAs, and checkout does not keep Git credentials.
Regression tests enforce these workflow boundaries.

A review on 2026-11-14 covered nine executed jobs across the available release
and version-request runs, plus the public 1.2.10 ZIP and receipt. Token values
in those logs were masked. No recognizable unmasked GitHub, AWS, or
private-key credential pattern was found. The ZIP contained 19 runtime and
license files. The receipt contained release identifiers, hashes, and the
CurseForge file ID. The review covers those logs and assets. It does not cover
every secret that might exist in repository history or in private artifacts.

Someone who can change `main` or the workflow definitions is trusted. Script
checks do not replace repository access control. For a stricter deployment
policy, use a protected GitHub Environment with restricted deployment refs and
store the CurseForge token there. That needs a change in repository settings
and a move of the secret. These workflows do not turn it on. Revoke a token
that was shared outside the Actions secret store once the diagnostic session
is finished.
