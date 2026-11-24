# WoW Forever Addons

Addons for World of Warcraft: Forever. Each addon has its own version and its own release. CI is shared.

## Addons

| Addon | Purpose |
| --- | --- |
| [Compact Addon Buttons](CompactAddonButtons/README.md) | Collects minimap buttons into a compact grid, with configurable columns, per-button exceptions, and several languages. |

## Repository structure

- Each addon lives in its own directory.
- [`addons.yml`](addons.yml) registers addon paths, tests, packaging rules, and CurseForge projects.
- [`.github/workflows/`](.github/workflows/) holds the shared CI and release workflows.
- Source stays readable. A release build minifies Lua and packs only runtime files, required assets, and the license.

A pull request runs tests, Lua security checks, and dependency audits for the addons it touches. Shared checks look for secrets and unsafe workflows. Package checks verify the ZIP and test the extracted addon. Details are in [CI.md](CI.md).

## Releases

Open Actions, then Next addon version. Pick the addon and a `patch`, `minor`, or `major` bump, review the generated pull request, and merge it. The workflow creates the addon tag, builds and verifies the package, uploads it to CurseForge, and publishes the GitHub Release.

Install the attached `AddonName-version.zip`, or the CurseForge download, into the client's `Interface/AddOns/` directory. GitHub's automatic Source code archives contain this repository. Use the addon ZIP, not those archives.

Configuration, previews, and deployment are in [RELEASING.md](RELEASING.md).
