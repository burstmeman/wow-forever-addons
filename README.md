# WoW Forever Addons

Addons for World of Warcraft: Forever. Each addon has its own version and its own release. CI is shared.

## Addons

| Addon | What it does |
| --- | --- |
| [Compact Addon Buttons](CompactAddonButtons/README.md) | Gathers minimap buttons into a small grid. You can set the columns, leave individual buttons on the minimap, and pick a language. |

## How the repo is laid out

- One directory per addon.
- [`addons.yml`](addons.yml) lists paths, tests, package rules, and CurseForge projects.
- [`.github/workflows/`](.github/workflows/) holds the shared CI and release jobs.
- Source in git stays readable. A release build minifies Lua and packs the runtime files, the assets the game needs, and the license.

A pull request tests the addons it touches. It also checks Lua and audits dependencies. Shared jobs look for secrets and unsafe workflows. Package jobs open the ZIP and test the unpacked addon. More detail is in [CI.md](CI.md).

## Releases

In Actions, run Next addon version. Pick the addon and `patch`, `minor`, or `major`. Review the pull request, then merge it. The workflow tags the addon, builds the package, checks it, uploads it to CurseForge, and publishes the GitHub Release.

Put `AddonName-version.zip` from that release, or the CurseForge file, in the client's `Interface/AddOns/` directory. GitHub also attaches Source code archives. Those are this repository, so install the addon ZIP.

Setup, preview builds, and upload rules are in [RELEASING.md](RELEASING.md).
