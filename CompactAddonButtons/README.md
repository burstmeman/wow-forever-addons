# Compact Addon Buttons

![Compact Addon Buttons icon](icon.png)

A drawer for minimap buttons in World of Warcraft: Forever, Interface 16001. It does not need other addons or libraries.

## Installation

Copy the whole `CompactAddonButtons` folder into the Forever client's `Interface/AddOns/` directory. The manifest has to land at `Interface/AddOns/CompactAddonButtons/CompactAddonButtons.toc`. Do not wrap the folder in another folder. Restart the client, or reload the UI, and enable Compact Addon Buttons in the addon list.

You can leave out the `tests` directory and this README. They are for development.

## Controls

| Action | Result |
| --- | --- |
| Left-click the addon button on the minimap | Open or close the icon popup next to the button |
| Right-click the addon button | Open the exceptions list |
| Drag the addon button | Move it around the minimap edge |
| Drag the settings header | Move the settings window |
| Check a button in Exceptions | Leave that button on the minimap |
| Language dropdown in settings | Use the client language, or pick one |
| Buttons per row dropdown in settings | Choose 1 to 12 columns (default: 6); saved per account |
| Search in settings | Filter the exceptions list by button name |
| Refresh in settings | Look for buttons that were just created |
| Escape, or left-click the addon button again | Close the popup |
| `/cab` or `/compactaddonbuttons` | Open or close the drawer |
| `/cab settings` | Open or close the exceptions list |
| `/cab refresh` | Scan for buttons again |

The popup is a tight grid of addon icons on a lightly see-through background. It is 1 to 12 columns wide, six by default, and as tall as the buttons need. The icon grid does not scroll. Right-click the launcher and choose Buttons per row to change that without a reload.

The popup sits next to the launcher. It opens toward the middle of the screen and stays inside the screen edges. Names and help text come from the original button tooltips.

Search and the exception list are in the larger settings window. Right-click opens it. Its position is saved on its own. Only that list scrolls.

Settings, language, exceptions, the settings window, and the minimap button position are saved per account. The window uses the game fonts and the game's own controls, with a dark background and a thin muted gold border.

The minimap button uses `Media/MinimapIcon.tga`: four gold-framed buttons in a 2 x 2 grid, drawn simply so it stays readable at launcher size. The file is an uncompressed 64 x 64, 32-bit RGBA texture, so the corners and the gaps stay transparent (16,428 bytes). The addon list uses `Media/Icon.tga`, the original uncompressed 64 x 64, 24-bit RGB picture (12,332 bytes). `icon.png` and `minimap-icon.png` are 128 x 128 pictures for this page. The game does not load them.

![Minimap launcher icon](minimap-icon.png)

## Languages

English is the default, and the fallback. The first time you open the addon, language is Automatic (client language). The included translations are:

| Language | Client locales |
| --- | --- |
| English | `enUS`, `enGB` |
| Russian | `ruRU` |
| Spanish | `esES`, `esMX` |
| German | `deDE` |
| French | `frFR` |

Right-click the minimap button, then use Language to override automatic detection. The choice is saved per account and updates the open UI without a reload. If the client language is not in the list, the addon uses English. A missing string also falls back to English, one key at a time.

Each language is a UTF-8 Lua file under `Locales/`. To add one, register its strings in a new file and list that file in the manifest after `Locales/enUS.lua`. The rest of the addon stays as it is:

```lua
local _, ns = ...
ns.Localization.Register("itIT", "Italiano", {
    TITLE = "Pulsanti addon",
    LANGUAGE = "Lingua",
    AUTO_LANGUAGE = "Automatico (lingua del client)",
    -- Omitted keys use English. See Locales/enUS.lua for the full dictionary.
})
```

Another addon can call `CompactAddonButtons.RegisterLocale(locale, displayName, strings, aliases)` after this one has loaded.

- Extra strings for a locale that already exists are merged in. The language menu does not gain a second entry.
- An optional aliases array maps more client locales onto that translation.
- Strings and language names are copied when you register them.
- Every translation has to be a string. A bad registration returns `false` and changes nothing.
- Registration refreshes the open UI, so a pack that loads late still applies.

`CompactAddonButtons.SetLanguage("frFR")` selects a language that is already registered. `SetLanguage("auto")` goes back to the client language. `GetLanguage()` returns the locale actually in use. An unknown manual choice returns `false` and leaves the saved choice alone.

## Code organization

Each module is a plain Lua table with one job. There is no framework and no class tree.

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

The drawer moves the original button into a grid cell and puts that cell above the popup, so the panel does not steal the click. Left-click, right-click, tooltips, and the button's other scripts still belong to the addon that made the button.

Drag scripts are off while the button is in the drawer. They come back when you mark it as an exception. The original parent, strata, frame level, and every anchor come back too, so the button stacks on the minimap the way it did before. Buttons are not resized. If the source addon hid a button, this one does not force it on screen.

Discovery uses `LibDBIcon-1.0` when that library is already loaded. It then looks through the minimap and the minimap backdrop for named addon icon buttons, including ones nested inside other minimap buttons. A scan every two seconds catches buttons created late and addons that load on demand.

LibDBIcon names are the stable ids for exceptions. If an exception was recorded before LibDBIcon loaded, it is moved to the library id when that is possible.

Game controls stay on the minimap. That includes tracking, mail, zoom, queue status, the clock, and the world map. Protected buttons stay out too. A button with no name, or one sitting in an odd place, may need its own addon to register it. A random UI frame is hard to tell apart from a game control. Turn off other minimap-button collectors, or they will fight this one over parents and anchors.

The drawer closes when combat starts. Opening it, and moving button parents or anchors, waits until combat ends. The launcher stays on the minimap. If you try to open the drawer in combat, the addon prints a short message.

## Optional registration API

If your minimap button is unusual, register it after Compact Addon Buttons has loaded:

```lua
if CompactAddonButtons then
    CompactAddonButtons.RegisterButton("MyAddon", "My Addon", myMinimapButton)
end
```

Use a key that stays the same and does not collide with another addon. A call made before login is fine. A second registration of the same button object is ignored. A protected button is rejected. You do not need LibDataBroker or LibDBIcon.

## Verification

From the repository root, with Python 3.12:

```powershell
python -m pip install -r CompactAddonButtons/tests/requirements.txt
python CompactAddonButtons/tests/run.py
```

The runner can also use the local `.tools/lua-test-runtime` install. It loads this addon's manifest in Lua 5.1 against a UI double that keeps state. Sixteen scenarios cover the five bundled languages, the English and Spanish locale aliases, a client language that is not bundled, and both a fresh install and migrated settings.

The suite also covers:

- startup, and saved settings that are invalid
- LibDBIcon and custom discovery
- native and protected controls left alone
- hidden buttons
- the original click and hover behavior
- moving buttons
- putting an exception back, including several anchors and drag scripts
- moving an exception onto its library id
- the periodic scan, search, and slash commands
- saved positions, a square minimap, and popup bounds
- work that waits until combat ends

Localization checks cover the dropdown callbacks, text that updates immediately, fallback per missing key, complete dictionaries, a saved manual choice, bad registrations, metadata kept apart from the caller's table, packs that load late, and a language change during combat.

Run the same checks in the Forever client. The harness has not checked the real layout, real callbacks from other addons, or taint and protected frames. Before a release:

1. Confirm `/dump select(4, GetBuildInfo())` reports `16001`.
2. Enable several addons that have minimap buttons. Only this addon's button, plus the exceptions you chose, should stay on the minimap.
3. Open the drawer. Try left-click, right-click, and the tooltip on each collected button.
4. Toggle exceptions, move the settings window and the launcher, reload, and check that those choices are still there. The icon popup should open beside the launcher, not at the saved settings position.
5. Try a source addon's own show and hide setting, and a button from an addon that loads on demand.
6. Enter and leave combat with the drawer open. Watch for Lua errors, blocked actions, and taint.
7. With more than 36 buttons, and with other column counts, the icon grid should grow and still not scroll. Also check the settings list scroll, an empty popup, Russian text, custom minimap shapes, a launcher near each screen edge, and the client's UI scale.
8. Pick each language in the dropdown. Look for clipped labels and tooltips, reload, and confirm the choice is still selected. Switch back to automatic.
