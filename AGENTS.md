# Repository guide for coding agents

This file applies to the complete repository. Read [CI.md](CI.md) before changing
checks, and [RELEASING.md](RELEASING.md) before changing packaging or publication.
A more specific `AGENTS.md` can add rules for its own directory.

## Project map

This is a monorepo of World of Warcraft: Forever addons. Each addon is one
directory with its own `.toc` version, tests, and release. There is no
repository-wide version. `addons.yml` is the registry of paths, status, tests,
security allowances, and CurseForge configuration.

`CompactAddonButtons/` is the current addon. It collects minimap buttons into a
compact grid. Its `.toc` is the load order. Treat that order as an API: when
you add, remove, or move a runtime file, update the manifest and keep the file
after its dependencies.

Shared tooling lives in `.github/`. A change there can affect every addon.
Addon behavior stays inside the addon directory unless the task asks for shared
tooling.

## Runtime ownership

- Runtime files start with `local _, ns = ...`. Put internal modules on `ns`.
  The public addon table is `CompactAddonButtons` in `API.lua`.
  `BetterAddonButtons` is the compatibility alias and points at the same table.
  Do not create another global. New exports belong in `addons.yml` under
  `security.globals`.
- `Bootstrap.lua` owns login, combat, slash commands, and the periodic scan.
  `Application.lua` owns the ready/pending lifecycle. Button identity lives in
  `Buttons.lua`, capture and anchoring in `Collection.lua`, and discovery in
  `Discovery.lua`.
- Saved settings and language choice live in `Settings.lua` and
  `Localization.lua`. Locale packs register through
  `ns.Localization.Register`. User-visible strings are keys in those packs,
  not a `L["text"]` table.
- Frames live under `UI/`. `UI/Window.lua` owns the grid and the exceptions
  panel. `UI/MinimapButton.lua` owns the launcher. Widget helpers stay in
  `UI/Widgets.lua`.
- Follow the module already on `ns` instead of adding a second registry for
  the same responsibility.

## Persistent data

`CompactAddonButtonsDB` and `BetterAddonButtonsDB` survive addon reloads. Both
names are saved variables. Players may still have the compatibility name.

- Treat persisted table shapes, absent fields, `nil`, and `false` as
  compatibility behavior. Malformed saved data must recover, not trap login.
- Do not rename or drop a saved field unless old data still loads.
- Keep the public alias `BetterAddonButtons` working. Do not add reminders
  about previous addon names to README files.

## Supported game versions

The supported client is World of Warcraft: Forever. CompactAddonButtons
declares `## Interface: 16001`. CurseForge publication uses game version type
`88568` and the exact version name `1.60.1` from that addon's `release` entry.

- Do not assume a retail, Classic, or other-flavor API exists. Check the
  function against Forever before using it.
- Always consult <https://warcraft.wiki.gg/wiki/World_of_Warcraft_API> for
  questions about the WoW API. Each function's page documents its signature,
  behavior, and the client flavors and patch versions that support it. Trust
  the wiki over memory when the two disagree.
- Reference <https://warcraft.wiki.gg/wiki/API_change_summaries> for
  historical changes to an API, such as a rename, a removal, or a changed
  signature in a given patch.
- A release uploads one addon. Do not change another addon's version, tag, or
  CurseForge project as part of unrelated work.

## Secure execution and taint

WoW separates secure Blizzard code from tainted addon code. Taint that spreads
into secure code blocks protected actions and raises errors for users. See
<https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting> for the model.

- Do not write to Blizzard frames, globals, or tables that secure code reads.
  Hook a Blizzard function with `hooksecurefunc`. `Collection.lua` uses that
  for button methods whose layout must be reapplied.
- During combat lockdown, WoW blocks specific operations on a protected frame,
  such as show, hide, move, resize, anchor, and secure attribute changes. See
  <https://warcraft.wiki.gg/wiki/API_InCombatLockdown> for the restricted set.
  Before such an operation, follow the addon: check `InCombatLockdown()` and,
  for a captured button, `IsProtected()`, then defer the change.
- `Application.lua` records pending work and applies it on
  `PLAYER_REGEN_ENABLED`. Use that lifecycle instead of touching protected
  frames while combat lockdown is active.

## Code conventions

- Use Lua 5.1 syntax. WoW runs a customized Lua 5.1 that removes standard
  libraries such as `io` and most of `os`, and adds helpers such as
  `strsplit` and `tinsert`. See
  <https://warcraft.wiki.gg/wiki/Lua_functions> for the full list. The CI
  allowlist is the WoW and Lua globals this repository permits.
- Use four spaces for indentation, LF line endings, a final newline, and no
  trailing whitespace. Do not add semicolons. In an existing file, follow its
  local form.
- Write documentation and code comments in English.
- Set the CompactAddonButtons manifest author to `burstmeman`.
- Localize every new user-visible string through `ns.Localization.Register`
  in each shipped locale pack.
- Keep changes narrow. Do not mix a fix with unrelated formatting, renaming,
  or speculative refactoring. Stay inside the requested addon directory, or
  inside explicitly requested shared tooling.
- Prefer a clear local branch over a new abstraction when the abstraction does
  not remove a real invalid state, repeated decision, or repeated lookup.
- Explain non-obvious ownership, lifecycle, and compatibility decisions. Do
  not add comments that only repeat the code.
- Do not add a comment at every place you change. Never repeat the same
  comment at more than one site. When a change needs a reason, explain it
  once, in the commit message or at the one place a reader would look.

## Branches and commits

- Never create branches under `codex/`.
- Use only `release/`, `feat/`, or `chore/` branch prefixes.
- Release branches use `release/<AddonName>/<version>`.
- Use Commitizen / Conventional Commits messages: `type(scope): description`.
- Release commits and pull-request titles use `chore(<AddonName>): release <version>`.
- Use Conventional Commits titles for other pull requests as well.
- Never add coauthors or `Co-authored-by` trailers. An agent signature in a
  pull-request body or a review comment is a footer, not a git trailer.

## Tooling and generated output

Do not hand-edit generated output unless the task explicitly asks for it and
you use the owning command.

- The addon dropdown in `.github/workflows/next-release.yml` is generated.
  After a registry change, run `python .github/ci/next_release.py sync`
  instead of editing the choice list by hand.
- Release packaging copies the allowlist in `addons.yml`, minifies Lua with
  the pinned LuaSrcDiet wrapper, and writes a deterministic ZIP. Repository
  sources stay readable. Do not commit minified output or `.tools/`.
- Lua style is StyLua 2.6.0 with the root `stylua.toml` (Lua 5.1, four spaces,
  LF). `python .github/ci/lua_format.py fix <AddonName>` rewrites the addon.
  `check` is what CI runs. Do not add a second formatter config or an inline
  `stylua:` directive.
- Publication, CurseForge tokens, and GitHub release receipts belong to
  `.github/ci/release.py`. Do not upload a package by hand while that workflow
  is running.
- This repository does not use `.pkgmeta` or an external addon packager.
  Packaging rules stay in `addons.yml` and `RELEASING.md`.

## Reasoning before changes

Source-based reasoning is required for behavior changes. A passing harness or
CI job does not replace it. Before editing, explain the affected behavior and,
for fixes, the actual failure path. Include file references and the rule the
change must preserve. Keep facts, assumptions, and unknowns distinct.

- Trace the real entry point, callers, and state owner. Check `.toc` order,
  saved-variable compatibility, and the Forever API contract. A direct call
  to an internal function does not prove runtime reachability.
- Trace the affected lifecycle: load, login, scan, combat start, combat end,
  and saved-data recovery as applicable. For deferred work, identify the
  actual event boundary and its ordering. Do not invent an interleaving
  merely because a harness can construct it.
- Treat a guard, fallback, or swallowed error as a behavior change. Determine
  whether missing state is valid or indicates a broken caller contract.
  Repair the cause; do not silently accept invalid state to make a test pass.
- Tie each added branch or helper to a demonstrated defect or an explicit
  requirement. Before finishing, ask what assumption would make the fix
  unnecessary or wrong, then check that assumption against the source.
  Search for contradictory evidence, not only examples that support the fix.

## Validation

WoW supplies runtime behavior that the local Lua harness does not reproduce.
Use source inspection and the documented client contracts as the primary local
evidence. Verify behavior in World of Warcraft: Forever when available. When
it is not available, state the specific in-game behavior that remains
unverified; do not replace that gap with a stronger test claim.

`CompactAddonButtons/tests/wow_mock.lua` is the focused UI double for this
addon. Extend it when a changed call needs a WoW API the addon already uses.
Do not grow it into a general client, and do not add a second mock. Identify
what the double stubs before treating a green run as evidence. Synthetic
states can test robustness, but they do not establish a supported failure path.

For every change:

1. Run `git diff --check`.
2. For a `.github/ci` change, run `python -m unittest discover -s .github/ci -p 'test_*.py' -v`.
3. For an addon change, run that addon's `tests/run.py` with Python 3.12 and
   `lupa==2.8`. Release checks also set `ADDON_RUNTIME_PATH` to the extracted
   package. Parse changed Lua with `luac -p` only when the compiler is Lua 5.1.
   A newer local `luac` is not authority for compatibility.
4. Run `python .github/ci/security.py <AddonName>` when Luacheck is available.
   This matches the addon CI job. Run `python .github/ci/lua_format.py check <AddonName>`
   after `python .github/ci/lua_format.py setup`. Use `fix` to rewrite Lua that
   the check rejects.
5. Review the final diff against the source-based explanation. Report the
   relevant evidence, checks actually run, and remaining uncertainty. Scale
   this explanation to the change; test counts alone are not validation.

Also check the relevant boundaries:

- For a new or moved runtime file, inspect the `.toc` load order and the
  release file allowlist.
- For saved data, validate a missing table, a malformed table, and the
  compatibility saved-variable name.
- For combat-sensitive UI, validate both the lockdown path and
  `PLAYER_REGEN_ENABLED`.
- For a shared `.github/` change, remember that CI selects every addon.

Pull-request CI runs registry tests, the addon suite, Luacheck, secret
scanning, and workflow analysis. It does not load the addon in the Forever
client, so it cannot prove frame strata, protected-frame behavior, or real
minimap discovery. Do not say a check passed unless you ran it or GitHub
reports it as passed.

## Git and review

- Start a focused topic branch from current `main`.
- Keep each commit reviewable. Keep the pull request title and description
  clear about the reason, behavior change, risks, and validation, and update
  them when new commits change what the pull request does.
- Read all current review comments before you revise a pull request. When a
  comment is addressed, reply to its thread with what changed and the commit
  hash, then resolve the thread.
- Keep a reviewer's statement separate from your interpretation. Investigate
  vague feedback before changing code. If materially different fixes remain
  possible, explain the evidence and ask for clarification instead of
  presenting a guessed rationale as established fact.
- Sign agent-authored pull requests, issues, and review comments with a footer
  that names the agent and the model. Do not put that signature in a commit
  message or a `Co-authored-by` trailer. Example:

  ```markdown
  ---
  Written by an agent (Cursor, Grok 4.7).
  ```

- Preserve unrelated work in a dirty worktree.

## Keep this guide current

This guide is a living document. When a review correction teaches you a
durable, repository-wide rule or fact that this guide does not state, or shows
that a statement here is wrong, update `AGENTS.md` in the same pull request as
a separate commit.

- Record the rule, not the incident. Verify the statement against the
  repository first, write it in the guide's style, and put it in the section
  where an agent would look for it.
- Do not record feedback that only applies to one change.
- Correct or delete a wrong statement instead of adding a second one next to
  it. A wrong rule is worse than a missing one.
