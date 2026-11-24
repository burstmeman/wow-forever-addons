# Memory and CPU review

Reviewed on 2026-11-14 with PUC Lua 5.1, Lupa 2.8, and the stateful WoW UI test double. The numbers come from that harness. They are not a profile from the live client.

## What changed

After the UI pools had warmed up, a stable set of registered buttons did not grow Lua memory without bound. It also created no new frames and no duplicate secure hooks.

The old two-second poll still did extra work while the window was closed. It sorted a list that had not changed, rebuilt both dropdowns, and laid out the window.

What the code does now:

- It sorts when a button is added or renamed.
- It rebuilds a menu when the language changes, a locale is registered, or the column setting changes.
- A closed window still updates labels and settings. It waits to lay itself out until you open it.
- The two-second scan still runs, so a button that loads late still shows up.
- If that scan adds nothing and renames nothing, and combat did not postpone an update, a closed window skips collection and layout.
- A button it already knows is not labeled again, and its icon is not inspected again.
- An open window moves anchors when the visible set, the labels, the exceptions, or the launcher position change.
- A collected button that is already centered on its slot is left where it is.

One local run, 3,600 poll callbacks, stands for two hours of timers with the window closed:

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

That small memory delta includes the tables used to measure. The times are from this mock on one machine. They do not say what the frame rate or the addon CPU will be in game. The regression checks count operations and retained memory. They do not compare timings.

## What the tests cover

`tests/run.py` runs all 16 locale and migration scenarios, then `performance_spec.lua`:

- 3,600 idle poll callbacks, two hours of simulated timer ticks.
- 36,000 idle frame callbacks, a simulated 60 Hz.
- 1,000 scans with the popup open and the same buttons.
- One outside `SetPoint` on a collected button, then 1,000 moves back onto its current slot.
- 1,000 cycles that open and close settings and the popup.
- 1,000 cycles that turn an exception on and off.
- Menus rebuilt after a setting or translation change, late buttons registered and sorted once, and the drag updater cancelled in combat.

After warm-up, a stable set of buttons must create no extra frames or hooks. It must not rebuild a menu that did not change, must not sort a list that did not change, and must keep extra Lua memory under 8 KiB for that phase. A closed window must not write text or anchors. An open drawer whose contents did not change must not write them either. CI runs the same suite on the unpacked, minified release package.

Slots and settings rows are pooled up to the most buttons seen in the session. Buttons and hooks stay tied to their owner for that session, so a real new button can raise the peak memory. The mock does not model client allocations, Blizzard menu pools, other addons' scripts, drawing cost, or how the client schedules frames. That needs a profile inside the client. This review did not change game files and did not turn client profiling on.
