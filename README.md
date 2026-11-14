# WoW Forever Addons

A collection of addons for **World of Warcraft: Forever**, with shared CI and independent versions and releases for each addon.

## Addons

| Addon | Purpose |
| --- | --- |
| [Compact Addon Buttons](CompactAddonButtons/README.md) | Collects minimap buttons into a compact grid, with configurable columns, per-button exceptions and multiple languages. |

## Repository structure

- Each addon lives in its own directory.
- [`addons.yml`](addons.yml) registers addon paths, tests, packaging rules and CurseForge projects.
- [`.github/workflows/`](.github/workflows/) contains shared CI and release automation.
- Source code stays readable; release builds minify Lua and package only runtime files, required assets and the license.

PR checks select affected addons and run tests, Lua security checks and dependency audits. Shared checks scan for secrets and unsafe workflows. Package checks verify the ZIP contents and test the extracted addon. See [CI.md](CI.md).

## Releases

Run **Actions → Next addon version**, select the addon and a `patch`, `minor` or `major` bump, then review and merge the generated PR. Automation creates the addon tag, builds and verifies its package, uploads it to CurseForge and publishes the GitHub Release.

Install the attached `AddonName-version.zip` or the CurseForge download into the client's `Interface/AddOns/` directory. GitHub's automatic **Source code** archives contain the repository and are not installable addon packages.

See [RELEASING.md](RELEASING.md) for configuration, previews and deployment details.
