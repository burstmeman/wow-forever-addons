# Memory and CPU review

Reviewed on 2026-11-14 with PUC Lua 5.1 through Lupa 2.8 and the stateful WoW UI test double. The numbers below come from that harness. They are not a live-client profile.

## Findings and changes

After the UI pools warmed up, a stable set of registered buttons showed no unbounded Lua-memory growth, no new frames, and no duplicate secure hooks. The original two-second poll still sorted an unchanged list, rebuilt both dropdown menus, and laid out the window while it was closed.

Sorting now runs when a button is added or renamed. Menu generation stays cached until the language, a locale registration, or the column preference changes. A closed window keeps labels and preferences up to date and waits to lay itself out until it opens. The two-second discovery poll still runs, so a late-loaded button still appears. When that poll adds or renames nothing, and combat did not defer an update, a closed window skips collection and layout. Known buttons are not labeled again and are not inspected for an icon again. An open window rewrites anchors when the visible set, labels, exceptions, or launcher position change. A collected button that is already centered on its slot is left alone.

One local run of 3,600 polling callbacks, two hours of timer intervals with the window closed, produced:

| Measurement | Before | After |
| --- | ---: | ---: |
| Button-list sorts | 3,600 | 0 |
| Dropdown menu generations | 7,200 | 0 |
| Radio choices constructed | 72,000 | 0 |
| Text writes | 28,800 | 0 |
| Anchor writes | 158,400 | 0 |
| Additional frames / secure hooks | 0 / 0 | 0 / 0 |
| Retained Lua-memory delta after full GC | 0.375 KiB | 0.375 KiB |
| Harness CPU time | 0.477 s | 0.071 s |

The small constant memory delta includes the measurement tables. These timings are from this mock on one host. They do not predict in-game frame rate or addon CPU use. Regression checks use operation counts and retained-memory bounds, not timings.

## Regression coverage

`tests/run.py` runs all 16 locale and migration scenarios, then `performance_spec.lua`:

- 3,600 idle polling callbacks, two hours of simulated timer intervals.
- 36,000 idle frame callbacks at a simulated 60 Hz.
- 1,000 scans with the popup visible and an unchanged button set.
- One foreign `SetPoint` on a collected button, then 1,000 reparents onto its current slot.
- 1,000 cycles that open and close settings and the popup.
- 1,000 exception enable and disable cycles.
- Menu invalidation after preference and translation changes, one-time registration and sorting of late buttons, and cancellation of the drag updater during combat.

After warm-up, a stable population must create no extra frames or hooks, rebuild no unchanged menu, sort nothing that did not change, and keep extra Lua memory under 8 KiB per phase. A closed window, and an open drawer whose contents did not change, must not write text or anchors. CI runs the same suite against the extracted minified release package.

Slots and settings rows stay pooled up to the largest button count seen in the session. Registered buttons and hooks stay tied to their owner for that session, so a genuinely new button can raise the high-water memory use. The mock does not model native client allocations, Blizzard menu pools, other addons' scripts, rendering cost, or real frame scheduling. Those need a separate client profile. This review did not change game files and did not turn on client profiling.
