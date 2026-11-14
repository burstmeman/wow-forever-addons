# Compact Addon Buttons

![Compact Addon Buttons icon](icon.png)

A standalone minimap button drawer for **World of Warcraft: Forever**, Interface **16001**. No required libraries or other addons.

Version **1.2.8**.

## Installation

Copy the entire `CompactAddonButtons` directory into the Forever client's `Interface/AddOns/` directory. The manifest must be at `Interface/AddOns/CompactAddonButtons/CompactAddonButtons.toc`, without an additional nested directory. Restart the client or reload the UI and enable **Compact Addon Buttons** in the addon list.

The `tests` directory and this README are development files and may be omitted when installing.

## Controls

| Action | Result |
| --- | --- |
| Left-click the addon button on the minimap | Toggle a compact icon popup beside the button |
| Right-click the addon button | Open the exceptions list |
| Drag the addon button | Move it around the minimap edge |
| Drag the settings header | Move the settings window |
| Check a button in Exceptions | Keep that button on the minimap |
| Language dropdown in settings | Choose automatic detection or a specific interface language |
| Buttons per row dropdown in settings | Choose 1–12 columns (default: 6); saved per account |
| Search in settings | Filter the exceptions list by button name |
| Refresh in settings | Immediately discover newly created buttons |
| Escape or left-click the addon button again | Close the popup |
| `/cab` or `/compactaddonbuttons` | Toggle the drawer |
| `/cab settings` | Toggle the exceptions list |
| `/cab refresh` | Rescan buttons |

The popup contains only addon icons in a tight grid with a lightly translucent background and fits its size to the number of visible buttons: a configurable 1–12 columns (six by default) and as many rows as needed. The icon grid has no scrolling or scrollbar. Right-click the launcher and choose **Buttons per row** to change the grid without reloading. It anchors directly beside the launcher, opens toward the screen interior, and stays clamped to the screen. Original button tooltips provide names and help. Search and exception controls appear in the larger settings view opened with right-click; its position is saved independently. Only the settings list scrolls.

Settings, language preference, exceptions, and settings-window/minimap positions are saved per account. The window uses game fonts, native controls, a dark background, and a thin muted gold border.

The minimap launcher and the in-game addon list share `Media/Icon.tga`: an uncompressed 64 x 64, 24-bit RGB texture (12,332 bytes). `icon.png` is a 128 x 128 preview for this page; the game does not load it. Both are resized from the supplied artwork without changing its composition.

## Languages

English is the default and fallback language. On first use, the language preference is **Automatic (client language)**. The bundled translations are:

| Language | Client locales |
| --- | --- |
| English | `enUS`, `enGB` |
| Russian | `ruRU` |
| Spanish | `esES`, `esMX` |
| German | `deDE` |
| French | `frFR` |

Right-click the minimap button, then use **Language** to override automatic detection. A manual choice is saved per account and updates the existing interface without reloading. Unsupported client languages use English. Missing translation keys also fall back to English individually.

Each language is a UTF-8 Lua file under `Locales/`. To bundle another language, register its strings in a new file and add that file to the manifest after `Locales/enUS.lua`. The rest of the addon requires no changes:

```lua
local _, ns = ...
ns.Localization.Register("itIT", "Italiano", {
    TITLE = "Pulsanti addon",
    LANGUAGE = "Lingua",
    AUTO_LANGUAGE = "Automatico (lingua del client)",
    -- Omitted keys use English. See Locales/enUS.lua for the full dictionary.
})
```

External translation addons can use `CompactAddonButtons.RegisterLocale(locale, displayName, strings, aliases)` after this addon loads. Registering more strings for an existing locale merges them without duplicating the language menu entry. An optional aliases array maps additional client locales to the translation. Strings and language metadata are copied on registration. Translations must be strings; invalid registrations return `false` without changing the registry. Registration also refreshes the current interface, so late-loaded translations work.

`CompactAddonButtons.SetLanguage("frFR")` selects a registered language; `SetLanguage("auto")` restores client detection. `GetLanguage()` returns the effective canonical locale. Unsupported manual selections return `false` without changing the saved preference.

## Code organization

Modules are plain Lua tables with explicit responsibilities; there is no framework or class hierarchy.

| Module | Responsibility |
| --- | --- |
| `Buttons.lua` | Button identities, duplicate prevention, ordering, and matching; no frame operations |
| `Collection.lua` | Capture/restore button state and maintain collected anchors |
| `Discovery.lua` | Discover LibDBIcon/custom buttons and exclude native/protected controls |
| `Settings.lua` | Saved variables, validation, persistence, and migration |
| `Localization.lua`, `Locales/` | Translation registry, locale resolution, English fallback, dictionaries |
| `UI/Window.lua` | Render the compact popup and settings; dispatch user actions |
| `UI/MinimapButton.lua` | Launcher appearance, minimap geometry, dragging, and tooltips |
| `UI/Widgets.lua` | Shared frame styling and small widget factories |
| `Application.lua` | Coordinate discovery, collection, preferences, and combat restrictions |
| `Bootstrap.lua`, `API.lua` | WoW events, slash commands, and the public extension API |

## How collection works

The drawer reparents the original button into a grid cell and places it above the popup panel so the panel cannot intercept its mouse input. Left-click, right-click, hover tooltips, and other original button scripts continue to belong to the source addon. Drag scripts are temporarily disabled inside the drawer and restored when a button becomes an exception. Original parent, frame strata, frame level, and all anchor points are restored too, so excluded buttons regain their minimap stacking order immediately. Buttons are not resized, and buttons hidden by their source addon are never forcibly shown.

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

The runner also supports the existing repository-local `.tools/lua-test-runtime` installation. It executes the actual manifest in Lua 5.1 with a stateful UI double. Sixteen scenarios cover all five bundled languages, English/Spanish locale aliases, an unsupported client language, and fresh/migrated settings.

Coverage includes startup and invalid saved settings, LibDBIcon/custom discovery, exclusion of native/protected controls, hidden buttons, original click/hover behavior, repositioning, exception restoration with multiple anchors and drag scripts, identity migration, periodic scans, search, slash commands, saved positions, square minimaps, popup bounds, and combat deferral. Localization checks cover actual dropdown callbacks, immediate text updates, per-key fallback, complete bundled dictionaries, manual choice persistence, invalid registrations, metadata isolation, late translation packs, and language changes during combat.

These tests do not replace a live Forever client check. Visual layout, real third-party callbacks, and client taint/protection behavior have not been verified in game for this addon. Before release:

1. Confirm `/dump select(4, GetBuildInfo())` reports `16001`.
2. Enable several installed addons with minimap buttons; verify only the addon button and chosen exceptions remain on the minimap.
3. Open the drawer and test each collected button's left/right clicks and tooltips.
4. Toggle exceptions, move the settings window/launcher, reload, and check persistence. Check that the icon popup still opens beside the launcher rather than at the saved settings position.
5. Test a source addon's own show/hide setting and a load-on-demand button.
6. Enter and leave combat with the drawer open; check for Lua errors, blocked actions, and taint.
7. Check that the icon grid expands without scrolling with more than 36 buttons and different column counts. Check settings-list scrolling, an empty popup, Russian text, custom minimap shapes, launchers near each screen edge, and the client's UI scale.
8. Select each language in the native dropdown, check translated labels/tooltips for clipping, reload, and verify that the choice persists. Switch back to automatic detection.
