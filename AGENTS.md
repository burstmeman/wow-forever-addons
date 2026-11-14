# Repository instructions

## Branches and commits

- Never create branches under `codex/`.
- Use only `release/`, `feat/`, or `chore/` branch prefixes.
- Release branches use `release/<AddonName>/<version>`.
- Use Commitizen / Conventional Commits messages: `type(scope): description`.
- Release commits and PR titles use `chore(<AddonName>): release <version>`.
- Use Conventional Commits titles for other pull requests as well.
- Never add coauthors or `Co-authored-by` trailers.

## Addon changes

- Keep changes confined to the requested addon or explicitly requested shared tooling.
- Set the CompactAddonButtons manifest author to `burstmeman`.
- Write documentation and code comments in English.
- Do not add reminders about previous addon names to README files.
