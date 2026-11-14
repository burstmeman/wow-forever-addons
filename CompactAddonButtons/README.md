# Compact Addon Buttons

A standalone minimap button drawer for **World of Warcraft: Forever**, Interface **16001**. No required libraries or other addons.

Version **1.1.0**, previously named **BetterAddonButtons**.

## Installation

Copy the entire `CompactAddonButtons` directory into the Forever client's `Interface/AddOns/` directory. The manifest must be at `Interface/AddOns/CompactAddonButtons/CompactAddonButtons.toc`, without an additional nested directory. Restart the client or reload the UI and enable **Compact Addon Buttons** in the addon list.

The `tests` directory and this README are development files and may be omitted when installing.

When upgrading from BetterAddonButtons, remove or disable its old addon folder before enabling CompactAddonButtons. Keep its account-wide `WTF/Account/<account>/SavedVariables/BetterAddonButtons.lua` file for the first login: saved exceptions and positions are imported automatically. `/bab` and `/betteraddonbuttons` remain aliases, and the old optional registration API remains available.

## Controls

| Action | Result |
| --- | --- |
| Left-click the bag button on the minimap | Toggle a compact icon popup beside the button |
| Right-click the bag button | Open the exceptions list |
| Drag the bag button | Move it around the minimap edge |
| Drag the settings header | Move the settings window |
| Check a button in Exceptions | Keep that button on the minimap |
| Search in settings | Filter the exceptions list by button name |
| Refresh in settings | Immediately discover newly created buttons |
| Escape or left-click the bag button again | Close the popup |
| `/cab` or `/compactaddonbuttons` | Toggle the drawer |
| `/cab settings` | Toggle the exceptions list |
| `/cab refresh` | Rescan buttons |

The popup contains only addon icons and fits its size to the number of visible buttons: up to five columns and six rows, with scrolling for larger collections. It anchors directly beside the launcher, opens toward the screen interior, and stays clamped to the screen. Original button tooltips provide names and help. Search and exception controls appear in the larger settings view opened with right-click; its position is saved independently.

Settings, exceptions, and settings-window/minimap positions are saved per account. The interface automatically uses Russian on a `ruRU` client and English otherwise. The window uses game fonts, native controls, a dark background, and a thin muted gold border.

## How collection works

The drawer reparents the original button into a grid cell. Left-click, right-click, hover tooltips, and other original button scripts continue to belong to the source addon. Drag scripts are temporarily disabled inside the drawer and restored when a button becomes an exception. Original parent and all anchor points are restored too. Buttons are not resized, and buttons hidden by their source addon are never forcibly shown.

Discovery uses an already loaded `LibDBIcon-1.0` when available, then searches the minimap and minimap backdrop for named addon icon buttons, including nested minimap buttons. A two-second scan catches delayed creation and load-on-demand addons. Names from LibDBIcon are used as stable exception identities. An exception discovered before LibDBIcon loads is migrated to its library identity when possible.

Game controls such as tracking, mail, zoom, queue status, the clock, and the world map are excluded. Protected buttons are excluded. Anonymous or unusually placed custom buttons may require explicit registration by their addon; arbitrary UI frames cannot reliably be distinguished from game controls. Other minimap button collectors should be disabled to avoid competing over button parents and anchors.

The drawer closes on entering combat. Opening it and changing button parents/anchors are deferred until combat ends. The launcher stays available on the minimap; attempting to open it during combat prints a short explanation.

## Optional registration API

An addon with an unusual minimap button can register it explicitly after Compact Addon Buttons has loaded:

```lua
if CompactAddonButtons then
    CompactAddonButtons.RegisterButton("MyAddon", "My Addon", myMinimapButton)
end
```

The key should be stable and unique. Registration supports pre-login calls, ignores duplicate button objects, and rejects protected buttons. There is no dependency on LibDataBroker or LibDBIcon.

## Verification

From the repository root, using Python 3.12:

```powershell
python -m pip install -r CompactAddonButtons/tests/requirements.txt
python CompactAddonButtons/tests/run.py
```

The runner also supports the existing repository-local `.tools/lua-test-runtime` installation. It executes the actual manifest in Lua 5.1 for English and Russian with a stateful UI double. Coverage includes startup and invalid saved settings, LibDBIcon and custom discovery, exclusion of native/protected controls, hidden buttons, original click/hover behavior, external repositioning, exception restoration with multiple anchors and drag scripts, late library identity migration, periodic scans, search, slash commands, saved positions, square minimaps, and combat deferral.

These tests do not replace a live Forever client check. Visual layout, real third-party callbacks, and client taint/protection behavior have not been verified in game for this addon. Before release:

1. Confirm `/dump select(4, GetBuildInfo())` reports `16001`.
2. Enable several installed addons with minimap buttons; verify only the bag button and chosen exceptions remain on the minimap.
3. Open the drawer and test each collected button's left/right clicks and tooltips.
4. Toggle exceptions, move the settings window/launcher, reload, and check persistence. Check that the icon popup still opens beside the launcher rather than at the saved settings position.
5. Test a source addon's own show/hide setting and a load-on-demand button.
6. Enter and leave combat with the drawer open; check for Lua errors, blocked actions, and taint.
7. Check scrolling with more than 30 buttons, an empty popup, Russian text, custom minimap shapes, launchers near each screen edge, and the client's UI scale.
