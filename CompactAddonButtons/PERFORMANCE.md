# Memory and CPU review

Reviewed on 2026-11-14 using PUC Lua 5.1 through Lupa 2.8 and the stateful WoW UI
test double. This is a code/stress-test review, not a live-client profiler result.

## Findings and changes

No unbounded retained Lua-memory growth, new frames or duplicate secure hooks
were observed for a stable set of registered buttons after warming the UI pools.
The original two-second polling path nevertheless sorted an unchanged list,
rebuilt both dropdown menus and laid out the window even while it was closed.

The application now sorts only when a button is added or renamed. Menu generation
is cached until the language, locale registration or column preference changes.
Closed windows retain updated labels/preferences but defer layout until opening.
The two-second discovery poll remains active so late-loaded buttons still appear.
A closed window skips collection and layout when that poll adds or renames nothing
and combat did not defer an update. Known buttons are not labeled or inspected for
an icon again. An open window rewrites anchors only when the visible set, labels,
exceptions, or launcher position change. A collected button that is already
centered on its slot is left untouched.

One local before/after run of 3,600 polling callbacks, representing two hours of
timer intervals with the window closed, produced:

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

The constant small memory delta includes measurement-table overhead. Timings are
from this mock on one host and cannot predict in-game FPS or addon CPU usage.
Regression checks use operation counts and retained-memory bounds, not timing.

## Regression coverage

`tests/run.py` runs all 16 locale/migration scenarios, then `performance_spec.lua`:

- 3,600 idle polling callbacks (two hours of simulated timer intervals).
- 36,000 idle frame callbacks at a simulated 60 Hz.
- 1,000 scans with the popup visible and an unchanged button set.
- One foreign `SetPoint` on a collected button, then 1,000 reparents onto its current slot.
- 1,000 cycles opening/closing settings and the popup.
- 1,000 exception enable/disable cycles.
- Menu invalidation after preference/translation changes, one-time registration
  and sorting of late buttons, and cancellation of the drag updater during combat.

After warm-up, stable-population phases must create no additional frames/hooks,
rebuild no unchanged menus, perform no redundant sorts, and retain less than 8 KiB
of extra Lua memory per phase. Closed windows and an unchanged open drawer must
not write text or anchors.
The same suite runs against the extracted minified release package in CI.

Slots and settings rows are deliberately pooled up to the largest observed button
count; registered buttons/hooks remain associated with their owner for the session.
New genuine buttons can therefore increase the high-water memory use. The mock
does not model native client allocations, Blizzard menu pools, other addons' scripts,
rendering cost or real frame scheduling. Those require a separate client profile;
this review did not change game files or enable client profiling.
