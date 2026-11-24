# Repository guide for coding agents

These rules cover the whole repository. Read [CI.md](CI.md) before you change
checks. Read [RELEASING.md](RELEASING.md) before you change packaging or
publication. A directory can add its own `AGENTS.md` for rules that apply only
there.

## Project map

This is a monorepo of World of Warcraft: Forever addons. Each addon is one
directory, with its own `.toc` version, tests, and release. There is no version
for the repository as a whole. `addons.yml` lists paths, status, tests, security
allowances, and CurseForge settings.

`CompactAddonButtons/` is the current addon. It gathers minimap buttons into a
small grid. The `.toc` file is the load order. Treat that order as part of the
contract. If you add, remove, or move a runtime file, update the manifest and
keep the file after the files it depends on.

Shared tooling lives in `.github/`. A change there can affect every addon. Keep
addon behavior inside the addon directory unless the task asks for shared
tooling.

## Runtime ownership

- Runtime files start with `local _, ns = ...`. Put internal modules on `ns`.
  The public addon table is `CompactAddonButtons` in `API.lua`.
  `BetterAddonButtons` is the compatibility alias and points at the same table.
  Do not create another global. New exports go in `addons.yml` under
  `security.globals`.
- `Bootstrap.lua` owns login, combat, slash commands, and the periodic scan.
  `Application.lua` owns the ready and pending lifecycle. Button identity is in
  `Buttons.lua`. Capture and anchoring are in `Collection.lua`. Discovery is in
  `Discovery.lua`.
- Saved settings and the language choice are in `Settings.lua` and
  `Localization.lua`. Locale packs register through
  `ns.Localization.Register`. User-visible strings are keys in those packs.
  Do not use an `L["text"]` table.
- Frames live under `UI/`. `UI/Window.lua` owns the grid and the exceptions
  panel. `UI/MinimapButton.lua` owns the launcher. Widget helpers stay in
  `UI/Widgets.lua`.
- Use the module that already exists on `ns`. Do not add a second registry for
  the same job.

## Persistent data

`CompactAddonButtonsDB` and `BetterAddonButtonsDB` survive a reload. Both names
are saved variables. A player may still have the compatibility name.

- Old table shapes, missing fields, `nil`, and `false` are compatibility
  behavior. Bad saved data must recover. Login must still succeed.
- Do not rename or drop a saved field unless old data still loads.
- Keep the public alias `BetterAddonButtons` working. Do not mention old addon
  names in README files.

## Supported game versions

The client is World of Warcraft: Forever. CompactAddonButtons declares
`## Interface: 16001`. CurseForge publication uses game version type `88568`
and the exact version name `1.60.1` from that addon's `release` entry.

- Do not assume a retail, Classic, or other-flavor API exists. Check the
  function on Forever before you use it.
- For WoW API questions, read
  <https://warcraft.wiki.gg/wiki/World_of_Warcraft_API>. Each function page
  lists the signature, the behavior, and the client flavors and patches that
  have it. If the wiki and your memory disagree, follow the wiki.
- For a rename, a removal, or a signature change, read
  <https://warcraft.wiki.gg/wiki/API_change_summaries>.
- A release uploads one addon. Do not change another addon's version, tag, or
  CurseForge project as part of unrelated work.

## Secure execution and taint

WoW keeps secure Blizzard code apart from tainted addon code. If taint reaches
secure code, protected actions stop working and the player sees errors. The
model is described at
<https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting>.

- Do not write to Blizzard frames, globals, or tables that secure code reads.
  Hook a Blizzard function with `hooksecurefunc`. `Collection.lua` does that
  for button methods whose layout has to be applied again.
- In combat lockdown, WoW blocks show, hide, move, resize, anchor, and secure
  attribute changes on a protected frame. The list is at
  <https://warcraft.wiki.gg/wiki/API_InCombatLockdown>. Before one of those
  calls, follow this addon: check `InCombatLockdown()`, and for a captured
  button also `IsProtected()`, then postpone the change.
- `Application.lua` records pending work and applies it on
  `PLAYER_REGEN_ENABLED`. Use that path. Do not touch a protected frame while
  combat lockdown is active.

## Code conventions

- Use Lua 5.1. WoW's Lua 5.1 drops libraries such as `io` and most of `os`,
  and adds helpers such as `strsplit` and `tinsert`. The full list is at
  <https://warcraft.wiki.gg/wiki/Lua_functions>. The CI allowlist is the WoW
  and Lua globals this repository permits.
- Indent with four spaces. Use LF, a final newline, and no trailing
  whitespace. Do not add semicolons. In a file that already has a local style,
  follow that file.
- Write docs and comments in English.
- Set the CompactAddonButtons manifest author to `burstmeman`.
- Every new string the player can see goes through `ns.Localization.Register`
  in each locale pack that ships.
- Keep a change small. Do not mix a fix with unrelated formatting, renaming,
  or a refactor you do not need. Stay in the addon directory you were asked to
  change, or in the shared tooling you were asked to change.
- Prefer a clear local branch of code over a new abstraction, unless the
  abstraction removes a real invalid state, a repeated decision, or a repeated
  lookup.
- Explain ownership, lifecycle, and compatibility when they are not obvious.
  Do not add a comment that only repeats the code.
- Do not comment every line you touch. Do not paste the same comment in more
  than one place. If a change needs a reason, write it once: in the commit
  message, or at the one place a reader would look.

## Branches and commits

- Never create branches under `codex/`.
- Branch names start with `release/`, `feat/`, or `chore/`.
- A release branch is `release/<AddonName>/<version>`.
- Commit messages follow Commitizen / Conventional Commits:
  `type(scope): description`.
- A release commit, and its pull request title, is
  `chore(<AddonName>): release <version>`.
- Other pull requests use Conventional Commits titles too.
- Never add a coauthor or a `Co-authored-by` trailer. An agent signature in a
  pull request, an issue, or a review comment is a footer. It is not a git
  trailer.

## Tooling and generated output

Do not edit generated output by hand unless the task says to, and you use the
command that owns that output.

- The addon dropdown in `.github/workflows/next-release.yml` is generated.
  After you change the registry, run `python .github/ci/next_release.py sync`.
  Do not edit the choice list by hand.
- Release packaging copies the allowlist in `addons.yml`, minifies Lua with
  the pinned LuaSrcDiet wrapper, and writes a ZIP that builds the same way
  every time. Source in the repo stays readable. Do not commit minified output
  or `.tools/`.
- Lua style is StyLua 2.6.0 with the root `stylua.toml` (Lua 5.1, four spaces,
  LF). `python .github/ci/lua_format.py fix <AddonName>` rewrites the addon.
  CI runs `check`. Do not add a second formatter config or an inline
  `stylua:` directive.
- Publishing, the CurseForge token, and GitHub release receipts belong to
  `.github/ci/release.py`. Do not upload a package by hand while that workflow
  is running.
- This repository does not use `.pkgmeta` or an outside addon packager.
  Package rules stay in `addons.yml` and `RELEASING.md`.

## Reasoning before changes

A behavior change needs an explanation from the source. A green harness or a
green CI job is not that explanation. Before you edit, say what behavior you
are changing. For a fix, name the path that fails. Name the files and the rule
the change has to keep. Keep facts, assumptions, and unknowns separate.

- Find the entry point the game calls, who calls it, and who owns the state.
  Check `.toc` order, saved-variable compatibility, and the Forever API. Calling
  an internal function yourself does not prove the game reaches it.
- Follow the lifecycle you touched: load, login, scan, combat start, combat
  end, and saved-data recovery, whichever apply. For work that waits, name the
  event where it runs and what runs before it. Do not invent an ordering just
  because the harness can build it.
- A new guard, a fallback, or a swallowed error is a behavior change. Decide
  whether the missing state is allowed or the caller is wrong. Fix the cause.
  Do not accept bad state so a test can pass.
- Every new branch or helper needs a bug you can show, or a requirement that
  asks for it. Before you finish, ask what assumption would make the fix
  unnecessary or wrong, then check that assumption in the source. Look for
  evidence that disagrees with the fix, not only evidence that agrees.

## Validation

The local Lua harness is not the WoW client. The main local evidence is the
source and the documented client contracts. Check the behavior in World of
Warcraft: Forever when you can. When you cannot, say which in-game behavior is
still unchecked. Do not write as if a test covered that gap.

`CompactAddonButtons/tests/wow_mock.lua` is the small UI double for this
addon. Extend it when a changed call needs a WoW API the addon already uses.
Do not turn it into a general client, and do not add a second mock. Say what
the double stubs before you treat a green run as evidence. A made-up state can
show how the code handles bad input. It does not prove that this failure
happens in the game.

For every change:

1. Run `git diff --check`.
2. For a `.github/ci` change, run `python -m unittest discover -s .github/ci -p 'test_*.py' -v`.
3. For an addon change, run that addon's `tests/run.py` with Python 3.12 and
   `lupa==2.8`. Release checks also set `ADDON_RUNTIME_PATH` to the unpacked
   package. Parse changed Lua with `luac -p` only when that `luac` is Lua 5.1.
   A newer `luac` on your machine does not decide compatibility.
4. Run `python .github/ci/security.py <AddonName>` when Luacheck is available.
   That matches the addon CI job. Run `python .github/ci/lua_format.py check <AddonName>`
   after `python .github/ci/lua_format.py setup`. Use `fix` to rewrite Lua that
   `check` rejects.
5. Read the final diff against the explanation from the source. Report the
   evidence, the checks you actually ran, and what is still unknown. Match the
   length of that report to the change. A count of tests is not the whole
   check.

Also check the edges you touched:

- A new or moved runtime file: look at `.toc` order and the release file list.
- Saved data: try a missing table, a bad table, and the compatibility saved
  variable name.
- Combat UI: try lockdown, and try `PLAYER_REGEN_ENABLED`.
- A shared `.github/` change: CI selects every addon.

Pull request CI runs the registry tests, the addon suite, Luacheck, secret
scanning, and workflow analysis. It does not load the addon in the Forever
client, so it cannot prove frame strata, protected-frame behavior, or real
minimap discovery. Do not say a check passed unless you ran it, or GitHub
shows it as passed.

## Git and review

- Start a focused branch from current `main`.
- Keep each commit easy to review. The pull request title and body should say
  why, what behavior changed, the risks, and how you checked it. Update that
  text when a new commit changes what the pull request does.
- Read the current review comments before you revise. When you address one,
  reply on that thread with what changed and the commit hash, then resolve it.
- Keep the reviewer's words separate from your reading of them. Look into vague
  feedback before you change code. If more than one fix still fits, show the
  evidence and ask. Do not write a guess down as if it were the reason.
- Sign agent-written pull requests, issues, and review comments with a footer
  that names the agent and the model. Do not put that signature in a commit
  message or a `Co-authored-by` trailer. Example:

  ```markdown
  ---
  Written by an agent (Cursor, Grok 4.7).
  ```

- Leave unrelated work in a dirty worktree alone.

## Keep this guide current

Update this guide when a review correction teaches a repository-wide rule that
is missing here, or shows that something here is wrong. Put that update in the
same pull request, as its own commit.

- Write down the rule, not the story of the review. Check the statement
  against the repo first. Use this guide's style, and put it in the section
  where an agent would look.
- Do not record feedback that applies to only one change.
- Fix or delete a wrong statement. Do not leave it in place and add a second
  one next to it. A wrong rule is worse than a missing one.
