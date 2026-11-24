# Shared addon CI

`addons.yml` lists the addons that are committed here. The version lives in each addon's `.toc`, not in that file. Status is one of `release`, `beta`, `development`, or `experiment`. A release or beta addon must have tests.

Tags and CurseForge uploads are described in [RELEASING.md](RELEASING.md). Release settings also live in `addons.yml`. The version stays in the `.toc`.

## Add an addon

Once the addon directory and its manifest exist, run:

```sh
python -m pip install -r .github/ci/requirements.txt
python .github/ci/addons.py register MyAddon --status development
```

Registration looks for `tests/run.py` and an optional `tests/requirements.txt`. Read the generated entry. Put the addon's exported globals under `security.globals`.

A test command is a list of arguments. It runs in the addon directory, with no shell. Use `python` so CI picks Python 3.12. Any other tool must already be on the Ubuntu runner, or come from the declared Python test dependencies. If you need another toolchain, add its setup to the shared runner. You do not need a workflow per addon.

Lua suites call `.github/ci/lua_tests.py`. The addon's `tests/run.py` names the specs in order. It does not hardcode the directory. The locale matrix and `ADDON_RUNTIME_PATH` are shared.

- Specs in the main list share one Lua state.
- A spec named in `once` runs one time, after that matrix.
- Release settings stay on that addon's `release` entry. Each directory keeps its own tag and CurseForge project.

CI refuses a committed `.toc` that sits outside a registered addon. It also refuses:

- duplicate or overlapping paths
- unknown fields
- unsafe paths
- a bad status
- a release or beta entry with no tests

A directory that is not in git is outside the registry.

## What runs

Every pull request runs:

- registry checks
- the CI policy unit tests
- Gitleaks, for secrets in commits
- an audit of CI's Python dependencies
- zizmor, for workflow security

If an addon changed, CI also runs its tests, audits its Python dependencies, and checks Lua syntax, globals, and security.

Jobs use a read-only token. They drop checkout credentials, get no repository secrets, and run on disposable GitHub-hosted runners. Actions are pinned by commit SHA. Dependabot opens update proposals.

Which addon gets tested:

- A change under a registered path selects that addon. A deletion counts.
- An edit to the registry selects only the new or changed entries.
- A `.github/` change selects every addon, because the shared checks may have changed.
- A docs change at the repo root does not rerun addon tests.
- A manual run tests every addon.
- A rename selects both directories.
- If an addon entry was deleted, CI checks the registry that remains. Every manifest still in the tree must belong to a registered addon.

In branch protection, require the aggregate `CI` status. It passes when no addon tests were needed. It fails if a job that should have run failed, was cancelled, or was skipped. Adding the workflow does not turn on branch protection. Set that in the repository settings.

## Security policy and limits

Luacheck checks runtime Lua against `.github/ci/luacheckrc`. StyLua 2.6.0 checks formatting.

`python .github/ci/lua_format.py setup` downloads the pinned StyLua archive for this machine and writes the binary under `.tools/`. That directory is not committed.

- `check` runs StyLua on every `.lua` file in the addon, tests included.
- `fix` rewrites those files.
- Both commands pass the repo `stylua.toml` with `--config-path` and `--no-editorconfig`, and they pass the file list themselves. An addon `stylua.toml`, `.styluaignore`, or `.editorconfig` cannot replace the style.
- An inline `stylua:` directive is rejected.
- The addon job and the release build run `check`.

`luacheckrc` is the shared list of UI APIs. It is passed with `--config`, so an addon cannot swap in its own config or an inline directive. Add a new WoW API there. An addon's own exports are `security.globals` in `addons.yml`, and they are writable globals for that directory only.

Tests skip the runtime API restriction, because the harness has to load files. A runtime manifest cannot load a test file, a file outside the addon, or an XML script.

A smaller scanner rejects:

- a `_G` lookup that is not an allowed literal
- an encoded string payload
- a network URL
- an inline lint suppression

Messaging, loader, and filesystem globals are not in the Luacheck allowlist, so using them fails the lint. If an addon needs chat, a loader, or another game API, extend the shared policy in review. Do not switch the check off to make it pass. The rules are strict and can flag a real new feature.

Gitleaks looks for credential-shaped text in pull request commits. `pip-audit` checks the declared Python dependencies for known advisories. Either check can miss a bad package or a secret. Lua libraries are checked only when their source is committed inside the addon. A library fetched from outside is not certified. CodeQL does not support Lua, so it is not used as a Lua security check here.

A green CI run can still miss a data leak. Obfuscated logic, a misused allowed callback, a third-party API, or a bug with no public advisory can get through. Read the runtime behavior. Read every change to workflows, the registry, and the security rules. A pull request can edit its own checks. Review and branch protection are what stop that edit from weakening them. These scanners do not launch the addon in a real WoW client.
