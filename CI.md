# Shared addon CI

`addons.yml` is the registry for addons committed to this repository. Versions live
in each addon's `.toc`, not in this registry. Status is one of `release`, `beta`,
`development`, or `experiment`. Release and beta addons must declare tests.

Per-addon tag packaging and CurseForge publication are described in [RELEASING.md](RELEASING.md).
Release settings also live in `addons.yml`; versions remain in each `.toc`.

## Add an addon

After adding an addon directory and its manifest, run:

```sh
python -m pip install -r .github/ci/requirements.txt
python .github/ci/addons.py register MyAddon --status development
```

Registration detects `tests/run.py` and its optional `tests/requirements.txt`.
Review the generated entry and declare the addon's exported globals under
`security.globals`. A test command is an argument list executed in the addon
directory, without a shell. Use `python` as the executable to select CI's Python
3.12. Other test tools must already be available on the Ubuntu runner or installed
as declared Python test dependencies. Add test setup support to the shared runner
when another toolchain is needed. No per-addon workflow is required.

Lua suites call `.github/ci/lua_tests.py`. The addon's `tests/run.py` names its
specs in order and does not hardcode the directory: the locale matrix and
`ADDON_RUNTIME_PATH` handling are shared. Specs in the main list share one Lua
state. A spec named in `once` runs a single time after that matrix. Release
settings stay on that addon's `release` entry, so each directory keeps its own
tag and CurseForge project.

CI rejects committed `.toc` files outside registered addon directories. It also
rejects duplicate or overlapping paths, unknown fields, unsafe paths, invalid
statuses, and release/beta entries without tests. Directories not committed to Git
are outside the registry's scope.

## What runs

Every PR runs registry validation, CI policy unit tests, Gitleaks secret scanning,
an audit of CI's Python dependencies, and zizmor workflow security analysis.
Changed addons additionally run their tests, Python dependency audit, and Lua
syntax/global-API/security checks. Jobs use a read-only token, do not retain checkout
credentials, do not receive repository secrets, and run on disposable GitHub-hosted
runners. Actions are pinned by commit SHA; Dependabot proposes updates.

A change below an addon's registered path selects that addon, including deletions.
A registry edit selects only new or modified entries. A `.github/` change selects
all addons because shared checking behavior may change. Root documentation changes
do not rerun addon tests. Manual runs test all addons. Renames select both affected
directories. Deleted addon entries are validated through the resulting registry;
remaining manifests must still belong to a registered addon.

Use the aggregate **CI** status as the required PR check in repository rules. This
stable status succeeds when no addon tests are needed, but fails if any applicable
job fails, is cancelled, or is unexpectedly skipped. Adding the workflow does not
itself enable branch protection; configure that separately in repository settings.

## Security policy and limits

Lua runtime code is checked with Luacheck against `.github/ci/luacheckrc`.
That file is the shared UI API allowlist and is passed with `--config`, so an
addon directory cannot replace it with its own config or an inline directive.
New WoW APIs are added there. An addon's own exports are `security.globals` in
`addons.yml` and are passed as writable globals for that directory only. Tests
are excluded from the runtime API restriction because their harness needs file
loading. Runtime manifests cannot load test files, files outside the addon, or
XML scripts.

A smaller scanner rejects `_G` lookups that are not an allowlisted literal,
encoded string payloads, network URLs, and inline lint suppression. Messaging,
loader, and filesystem globals are absent from the Luacheck allowlist, so using
them fails the lint. Addons requiring communication or additional game APIs
need a deliberate reviewed extension of the common policy; silently disabling
it is not supported.
These rules are intentionally conservative and can flag legitimate new features.

Gitleaks looks for credential patterns in PR commits; `pip-audit` checks declared
Python dependencies for known advisories. Neither detects every malicious package
or every possible secret. Lua dependency code must be committed inside the addon
to be covered by source checks; externally supplied libraries are not certified.
CodeQL does not support Lua and is not presented as a Lua security check here.

Passing CI is not proof that code cannot leak data. Obfuscated logic, abuse of
allowed callbacks or third-party APIs, and vulnerabilities without published
advisories can evade automated checks. Review runtime behavior and all changes to
workflows, the registry, and security rules. A PR can change its own checks; trusted
review and protected-branch rules are necessary to prevent weakening or bypassing
them. Scanners do not execute the addon in a real WoW client.
