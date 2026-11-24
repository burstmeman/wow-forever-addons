# Per-addon GitHub and CurseForge releases

Each addon has its own version, in `## Version` of its `.toc`, and its own tag:

```text
CompactAddonButtons/v1.2.8
AnotherAddon/v2.0.0
```

There is no version for the whole repository. A release picks one registered
addon. The release workflow does not test the others and does not upload them.
The tag version has to match that addon's manifest exactly. The tag has to
point at a commit that is already on `main`. Do not move a release tag, and do
not reuse one.

## Pick the next version in Actions

On `main`, open Actions, then Next addon version, then Run workflow.

1. Pick the addon in the dropdown.
2. Pick `patch`, `minor`, or `major`. The default is `patch`. From 1.2.8 those
   become 1.2.9, 1.3.0, and 2.0.0. If you add release notes, they become the
   changelog.
3. Run it. It opens a pull request that changes only that addon's manifest
   version, plus a request file under `release-requests/`. It does not publish.
   It does not change the game install.
4. Review the pull request and merge it after CI passes. A second job checks
   that the bot's pull request contains only the generated files. It then
   creates the addon tag on the merge commit, opens a draft GitHub Release,
   and starts Release addon so the package is published.

If GitHub asks you to approve workflows on that pull request, approve the CI
run before you merge. The repository has to let Actions open pull requests.
The setting is Settings, Actions, General, Workflow permissions, then "Allow
GitHub Actions to create and approve pull requests". The automation opens pull
requests. It does not approve them and it does not merge them. You do not need
an extra personal access token.

If creating the pull request returns HTTP 403, the workflow may already have
made the release branch. Turn on the setting above. Then start a new Next
addon version run from `main`, with the same addon, the same bump, and the
same notes. That run checks the original branch and keeps it. It does not
rewrite the branch, and it does not bump the version again.

Re-running an old failed job uses that job's old script. After you change the
automation, start a new workflow run. A branch someone edited, and a release
pull request that was cancelled, are left alone.

Automatic bumps accept a stable `major.minor.patch` version. For a prerelease
suffix, or a version you choose yourself, use the manual tag steps below. If
you ask for the same selection again while its release pull request is open,
you get that pull request back.

Generated branches look like `release/<AddonName>/<version>`, for example
`release/CompactAddonButtons/1.3.0`. The commit and the pull request title
follow Commitizen / Conventional Commits:
`chore(CompactAddonButtons): release 1.3.0`. Branch and commit rules are in
`AGENTS.md` and `.cz.toml`.

The addon dropdown is static YAML. It is generated from `addons.yml`. The
GitHub form does not fetch the list. Registration updates the choices. If you
edit the registry by hand, run:

```sh
python .github/ci/next_release.py sync
```

CI fails if the dropdown is stale. An addon with no release settings can still
be in the registry. It cannot open a release request until those settings exist.

## Configuration

An addon's `release` entry in `addons.yml` says which files may be packed, the
CurseForge project id, the game flavor type id, and the game version names.
CompactAddonButtons uses project 1804859, Forever type 88568, and 1.60.1.
That game version matches Interface 16001.

On upload, the workflow reads `/api/game/wow/versions` and turns each exact
`(gameVersionTypeID, name)` pair into a numeric file-version id. If that
Forever version is missing, it does not fill in Retail, Classic, a newer
version, or a nearby one. Type 88568 is also the Forever type used by the
upstream [WoW packager](https://github.com/BigWigsMods/packager/blob/master/release.sh).

A new addon uses the same workflow. After you register it, add its own
`release` block and CurseForge project id, and check the game versions and
file patterns. An addon with no release block cannot be released by accident.

The `files` list is Python globs, relative to the addon directory.

- The ZIP gets the matched runtime files and the repository license.
- Test directories, hidden files, `node_modules`, symlinks, and other
  non-runtime types are left out.
- A code glob is allowed. Every packed Lua or XML file must be named in the
  selected manifest, and every manifest entry must be in the ZIP. An extra
  manifest fails the build.
- A media or font file needs an exact path, not a glob. A preview or a source
  image nearby is not packed just because it is nearby.
- The ZIP has one root folder, named like the addon directory.
- CompactAddonButtons packs its manifest, 16 Lua files, two runtime TGA
  textures, and LICENSE. README files, preview PNGs, tests, and CI tooling
  stay out.

## One-time secret

In the repository's Actions secrets, set `CURSE_FORGE_DEPLOYMENT_TOKEN` to an
author Upload API token that can upload to every configured project. Do not
use the CurseForge for Studios read API key. Only the upload step sees the
secret, in the `X-Api-Token` header. It is not put in URLs, logs, ZIPs, or
pull request checks. The CurseForge project has to exist already, and the
token owner has to be allowed to upload to it.

## Publish

1. Update the addon's `.toc` version and merge that into `main`.
2. Push the matching tag. Or open a draft GitHub Release with notes, then run
   Release addon by hand with that tag and publish checked:

   ```sh
   git tag CompactAddonButtons/v1.2.8
   git push origin CompactAddonButtons/v1.2.8
   ```

3. Release addon checks that the tag is on `main`. It tests and security-checks
   only that addon, and builds a ZIP that comes out the same every time. A
   second job downloads that run's artifact by id, checks the hash, the tag,
   and the commit, and uses deploy scripts checked out from `main`. Before the
   artifact is stored, the build checks the file list and the file contents,
   unpacks the runtime into a temp directory, and tests it.
4. The job attaches the ZIP to the draft GitHub Release. If you pushed the tag
   with no draft, it creates one. It uploads the same ZIP to the CurseForge
   project. GitHub release notes become the CurseForge changelog. A tag pushed
   on its own gets a short default changelog. Open a draft with notes first if
   you want a longer one from the start.
5. After it saves the CurseForge file id and removes the pending marker, it
   publishes the GitHub Release. Every file is attached before that publish.
   That is what immutable GitHub releases require.

Both a tag event and a Release event can start the workflow. Runs for the same
tag wait their turn. A successful upload stores a JSON receipt on the GitHub
Release, with the CurseForge file id and the ZIP SHA-256. A later event, or a
rerun, skips that same upload. A Release this workflow created does not need
to start another workflow.

An immutable Release that is already public, and has no success receipt, cannot
take new files. That case stops before any CurseForge upload. Do not publish
the draft yourself while the deploy job is running. If an immutable Release
went public before the ZIP and the receipt were attached, ship a new addon
version.

Status in the registry maps to `release`, `beta`, or `alpha`. `development`
and `experiment` map to `alpha`. Tag suffixes `-alpha.1`, `-beta.1`, and
`-rc.1` pick alpha or beta on their own. A GitHub prerelease is uploaded as
beta, unless the tag already says alpha. The manifest has to carry the same
suffix as the tag.

## Preview without publishing

Run Release addon by hand with publish unchecked. Use a tag that matches the
version on `main`, such as `CompactAddonButtons/v1.2.8`. The tag does not have
to exist yet. This checks out `main`, checks the addon, tests it, and builds.
It does not publish, and it does not get the CurseForge secret. Download the
`release-package` artifact and look at the ZIP before you create a real tag.

The publish checkbox is for a tag that already exists. The job after a version
pull request merges leaves it unchecked. GitHub does not start workflows from
a tag or Release that the workflow token created. `workflow_dispatch` is the
exception. Leave publish unchecked when you only want to look at the package.

You can preview a package locally with no git tag:

```sh
python -m pip install -r .github/ci/requirements.txt
python .github/ci/lua_minify.py setup
python .github/ci/release.py preview --tag CompactAddonButtons/v1.2.8 --output .tools/release-preview
python .github/ci/release.py verify --output .tools/release-preview
```

Install the addon's test requirements before `verify`. Pull request CI also
runs `release.py check --addon NAME` for addons that have release settings.
That builds and checks a temp package. It needs no tag and no deploy
credentials.

## Minified runtime and package checks

The packager uses upstream [LuaSrcDiet 1.0.0-2](https://luarocks.org/modules/jirutka/luasrcdiet/1.0.0-2).
It strips comments and extra whitespace outside string literals. The source
package is pinned by SHA-256 in `lua_minify.py`. Setup checks that pin before
it loads anything. It unpacks only the modules it needs, plus the upstream
license files, into `.tools/luasrcdiet/`. That directory is gitignored. This
repo does not keep its own Lua parser or minifier.

CI installs Lua 5.1 and prepares that pinned package before tooling tests or
addon packaging. The publish job does not download the minifier and does not
run it. For a local preview, install Lua 5.1 and run the setup command above.
On Windows you can use the Lupa 2.8 Lua 5.1 runtime that the tests already
use. There is no way to skip the check.

Two checks have to pass before the result is kept: the source-token check, and
the Lua 5.1 binary equivalence check. The options keep names, operators, string bytes,
localization, and the order of files in the manifest. The minifier does not
rename globals or locals, does not hide the code, and does not emit bytecode.
Source in the repo stays readable. Line numbers in a packed traceback can
differ, because removed comments and whitespace change the line count.

Pull request CI and the release build both open the ZIP before they run the
packed code. A surprise path, a missing path, a duplicate path, changed
contents, or a bad hash fails the check. Tests run from the source checkout.
`ADDON_RUNTIME_PATH` points at the unpacked addon. A release-enabled harness
has to use that variable when it loads runtime files. Test code and fixtures
stay in the checkout. CompactAddonButtons runs all 16 Lua 5.1 scenarios on
the unpacked minified build, and again on the normal source.

Install `AddonName-version.zip`, or the CurseForge file. GitHub's Source code
ZIP and tar are the repository, tests and docs included. They are not the
addon you install, and they are not uploaded to CurseForge.

## When an upload fails

Before the upload POST, which cannot be safely repeated, the job writes a
`curseforge-pending-PROJECT.json` asset on the GitHub Release. If a timeout, a
crash, or a bad response leaves that marker and no success receipt, a rerun
will not POST again.

Look at the CurseForge project first.

- If the file was accepted, keep its id and fix the receipt to match.
- Delete the pending marker only after you know no file was created.

The job skips a blind retry so it does not publish the same file twice. Do not
delete a success receipt to force another upload. Publish a new version. If
only the last GitHub publish step failed, rerun the workflow. The receipt
already there blocks a second CurseForge upload, and the draft is published.

An HTTP error names the API host, the path, and the status. The remote body is
not printed. It can echo a secret.

A GitHub ZIP that is already attached must have the same SHA-256. It is not
replaced in place. The job fails on a moved tag, a changed artifact, a version
mismatch, a missing token, a game version it does not support, or a project
config it does not know.

A successful upload returns a CurseForge file id. CurseForge may still be
reviewing the file, so it might not be public yet. The code uses the
documented [Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api).
It does not use the read-only [Get Files API](https://docs.curseforge.com/rest-api/).

## Who can see the token

The build job can only read the repository. It has no CurseForge secret. It
runs the addon tests and zips the runtime files from the allowlist.

Publishing uses another runner. It downloads only that run's artifact, by id,
and runs deploy scripts from `main`. The ZIP is uploaded as data. Addon code
from the ZIP does not run in the job that has the deploy secrets. A publish
you start by hand has to run from `main`.

Only the last upload step gets `CURSE_FORGE_DEPLOYMENT_TOKEN` and its GitHub
token, as environment variables. They are not command-line arguments and not
URL parameters. A call that sends the token uses HTTPS, an exact approved
host, and no redirects. Artifact metadata has to match the known schema, and
the tag the workflow asked for, before any API call. Extra artifact fields are
not copied into the public receipt.

Jobs that can publish install only PyYAML, from `deployment-requirements.txt`,
as a wheel checked by SHA-256. The lock is for CPython 3.12 on Linux x86_64,
the same as the release runners. When you update it, take the wheel digest
from PyPI and check it with `pip download --require-hashes --only-binary=:all:`
on that platform. The wider CI test dependencies stay in `requirements.txt`.
GitHub actions are pinned to full commit SHAs. Checkout does not keep git
credentials. Tests check these limits.

A review on 2026-11-14 covered nine jobs that had actually run, across the
release and version-request runs that were available, plus the public 1.2.10
ZIP and its receipt. Token values in those logs were masked. No clear
unmasked GitHub, AWS, or private-key pattern showed up. The ZIP had 19 runtime
and license files. The receipt had release ids, hashes, and the CurseForge
file id. That review covers those logs and those files. It does not cover
every secret that might sit in git history or in private artifacts.

Someone who can change `main`, or the workflow files, is trusted. These checks
are not a substitute for repository access control. For a tighter setup, use a
protected GitHub Environment, limit which refs can deploy, and store the
CurseForge token there. That is a settings change, and the secret has to move.
These workflows do not turn it on. If a token was copied out of the Actions
secret store for a diagnosis, revoke it when that session is done.
