# Shared addon CI

`addons.yml` is the registry of addons committed to this repository. Each addon's version lives in its `.toc`, not in the registry. Status is `release`, `beta`, `development`, or `experiment`. A release or beta addon must declare tests.

Per-addon tags and CurseForge publication are described in [RELEASING.md](RELEASING.md). Release settings also live in `addons.yml`. Versions stay in each `.toc`.

## Add an addon

After the addon directory and its manifest exist, run:

```sh
python -m pip install -r .github/ci/requirements.txt
python .github/ci/addons.py register MyAddon --status development
```

Registration finds `tests/run.py` and an optional `tests/requirements.txt`. Review the generated entry and list the addon's exported globals under `security.globals`. A test command is an argument list, run in the addon directory, with no shell. Use `python` so CI selects Python 3.12. Any other test tool must already be on the Ubuntu runner, or be installed from the declared Python test dependencies. When another toolchain is needed, add its setup to the shared runner. No per-addon workflow is required.

Lua suites call `.github/ci/lua_tests.py`. The addon's `tests/run.py` names its specs in order and does not hardcode the directory. The locale matrix and `ADDON_RUNTIME_PATH` handling are shared. Specs in the main list share one Lua state. A spec named in `once` runs once after that matrix. Release settings stay on that addon's `release` entry, so each directory keeps its own tag and CurseForge project.

CI rejects a committed `.toc` outside a registered addon directory. It also rejects duplicate or overlapping paths, unknown fields, unsafe paths, invalid statuses, and a release or beta entry with no tests. A directory that is not committed is outside the registry.

## What runs

Every pull request runs registry validation, the CI policy unit tests, Gitleaks secret scanning, an audit of CI's Python dependencies, and zizmor workflow security analysis. A changed addon also runs its tests, a Python dependency audit, and Lua syntax, global-API, and security checks. Jobs use a read-only token, drop checkout credentials, receive no repository secrets, and run on disposable GitHub-hosted runners. Actions are pinned by commit SHA. Dependabot proposes updates.

A change under an addon's registered path selects that addon, including a deletion. A registry edit selects only new or modified entries. A `.github/` change selects every addon, because shared checking behavior may change. A root documentation change does not rerun addon tests. A manual run tests every addon. A rename selects both directories. Deleted addon entries are checked through the registry that remains. Every remaining manifest must still belong to a registered addon.

Use the aggregate `CI` status as the required pull request check in repository rules. That status succeeds when no addon tests are needed, and fails if any applicable job fails, is cancelled, or is skipped when it should have run. Adding the workflow does not turn on branch protection. Configure that in repository settings.

## Security policy and limits

Luacheck checks Lua runtime code against `.github/ci/luacheckrc`. StyLua 2.6.0 checks formatting. `python .github/ci/lua_format.py setup` downloads the checksum-pinned release archive for the current platform and writes the binary under `.tools/`. That directory is not committed. `check` runs StyLua in check mode on every `.lua` file in the addon, tests included. `fix` rewrites those files. Both commands pass the repository `stylua.toml` with `--config-path` and `--no-editorconfig`, and they pass files explicitly, so an addon config, `.styluaignore`, or `.editorconfig` cannot replace the style. An inline `stylua:` directive is rejected. The addon job and the release build run `check`.

`luacheckrc` is the shared UI API allowlist. It is passed with `--config`, so an addon directory cannot replace it with its own config or an inline directive. Add a new WoW API there. An addon's own exports are `security.globals` in `addons.yml`, passed as writable globals for that directory only. Tests are left out of the runtime API restriction because the harness has to load files. A runtime manifest cannot load a test file, a file outside the addon, or an XML script.

A smaller scanner rejects a `_G` lookup that is not an allowlisted literal, an encoded string payload, a network URL, and an inline lint suppression. Messaging, loader, and filesystem globals are absent from the Luacheck allowlist, so using them fails the lint. An addon that needs communication or another game API needs a reviewed extension of the common policy. Do not turn the policy off to get a check to pass. The rules are conservative and can flag a legitimate new feature.

Gitleaks looks for credential patterns in pull request commits. `pip-audit` checks declared Python dependencies for known advisories. Either one can miss a malicious package or a secret. Lua dependency code is covered only when it is committed inside the addon. An externally supplied library is not certified. CodeQL does not support Lua, so it is not used here as a Lua security check.

A green CI run can still miss a data leak. Obfuscated logic, misuse of an allowed callback or a third-party API, and a vulnerability with no published advisory can pass. Review runtime behavior and every change to workflows, the registry, and the security rules. A pull request can change its own checks. Trusted review and protected-branch rules are what stop that change from weakening the checks. The scanners do not run the addon in a real WoW client.
