-- Stress a stable button population; measure retained Lua memory after full GC.
local ns, frames, stats = TestUI.ns, TestUI.frames, TestUI.stats
assert(ns.Discovery.Label("LibDBIcon10_Alpha") == "Alpha")
assert(ns.Discovery.Label("BetaMinimapButton") == "Beta")
assert(ns.Discovery.Label("Button") == "Button", "a name that is only the word button stays unchanged")
local metricColumns, metricRows, metricWidth, metricHeight = ns.Window.GridMetrics(4, 6)
assert(
    metricColumns == 4 and metricRows == 1 and metricWidth == 134 and metricHeight == 38,
    "grid size follows the visible button count"
)
local emptyColumns, emptyRows, emptyWidth, emptyHeight = ns.Window.GridMetrics(0, 6)
assert(
    emptyColumns == 1 and emptyRows == 1 and emptyWidth == 210 and emptyHeight == 38,
    "an empty popup keeps a readable size"
)
TestUI.SetCombat(false)
ns.App.SetLanguage("enUS")
ns.App.SetColumns(6)
for _, entry in ipairs(ns.Buttons.All()) do
    ns.App.SetException(entry.key, false)
end
for i = 1, 25 do
    ns.App.Toggle(true)
    ns.Window.Close()
    ns.App.Toggle(false)
    ns.Window.Close()
end
local sorts, originalSort = 0, ns.Buttons.Sort
ns.Buttons.Sort = function(...)
    sorts = sorts + 1
    return originalSort(...)
end
local function sample()
    collectgarbage("collect")
    return {
        frames = #frames,
        hooks = stats.hooks,
        menus = stats.menus,
        choices = stats.choices,
        textWrites = stats.textWrites,
        textureWrites = stats.textureWrites,
        pointWrites = stats.pointWrites,
        memory = collectgarbage("count"),
        sorts = sorts,
    }
end
local function phase(name, count, callback)
    local before = sample()
    local started = os.clock()
    for i = 1, count do
        callback(i)
    end
    local elapsed = os.clock() - started
    local after = sample()
    local result = {
        name = name,
        iterations = count,
        seconds = elapsed,
        retainedKiB = after.memory - before.memory,
        frames = after.frames - before.frames,
        hooks = after.hooks - before.hooks,
        menus = after.menus - before.menus,
        choices = after.choices - before.choices,
        textWrites = after.textWrites - before.textWrites,
        textureWrites = after.textureWrites - before.textureWrites,
        pointWrites = after.pointWrites - before.pointWrites,
        sorts = after.sorts - before.sorts,
    }
    return result
end
local events
for _, frame in ipairs(frames) do
    if frame.events.PLAYER_LOGIN then events = frame end
end
local results = {}
ns.Window.Close()
results[#results + 1] = phase("idle-two-hours", 3600, function() events.scripts.OnUpdate(events, 2) end)
results[#results + 1] = phase("idle-high-fps", 36000, function() events.scripts.OnUpdate(events, 1 / 60) end)
ns.App.Toggle(false)
results[#results + 1] = phase("visible-scans", 1000, function() ns.App.Scan() end)
ns.App.Toggle(true)
results[#results + 1] = phase("settings-preview-scans", 1000, function() ns.App.Scan() end)
ns.Window.Close()
results[#results + 1] = phase("open-close", 1000, function()
    ns.App.Toggle(true)
    ns.Window.Close()
    ns.App.Toggle(false)
    ns.Window.Close()
end)
results[#results + 1] = phase("exception-toggle", 1000, function()
    local entry = ns.Buttons.All()[1]
    ns.App.SetException(entry.key, true)
    ns.App.SetException(entry.key, false)
end)
for _, result in ipairs(results) do
    assert(result.frames == 0 and result.hooks == 0, "stable populations must reuse frames and hooks")
    assert(result.retainedKiB < 8, "retained Lua memory must plateau after warm-up")
    assert(result.menus == 0 and result.choices == 0, "unchanged settings must not regenerate menus")
    assert(result.sorts == 0, "unchanged button lists must not be re-sorted")
    if result.name:find("^idle") or result.name == "visible-scans" or result.name == "settings-preview-scans" then
        assert(
            result.pointWrites == 0 and result.textWrites == 0 and result.textureWrites == 0,
            "unchanged windows must not be laid out or repainted"
        )
    end
end

-- Live preference/translation changes must still invalidate the appropriate menus.
local builds = stats.menus
assert(ns.App.SetColumns(7) and CompactAddonButtonsColumns.selectedText == "7")
assert(stats.menus == builds + 1)
ns.App.SetColumns(6)
builds = stats.menus
local label = ns.Localization.Text("SCAN")
assert(ns.Localization.Register("enUS", "English", { SCAN = "Updated scan label" }))
assert(stats.menus == builds + 2, "translation registration must invalidate labels and every menu")
ns.Localization.Register("enUS", "English", { SCAN = label })

-- Discovery remains active, while each genuinely new entry is hooked/sorted once.
local beforeSort, beforeHooks = sorts, stats.hooks
local late = CreateFrame("Button", "PerformanceLateMinimapButton", Minimap)
late.icon = true
ns.App.Scan()
assert(ns.Buttons.Find(late) and sorts == beforeSort + 1 and stats.hooks == beforeHooks + 2)
ns.App.Scan()
assert(sorts == beforeSort + 1 and stats.hooks == beforeHooks + 2)
local entry = ns.Buttons.All()[1]
assert(entry.collected and entry.slot)
local moved = phase("foreign-anchor", 1, function() entry.button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, 4) end)
assert(moved.pointWrites == 2, "a foreign point is cleared and the button returns to its slot")
local stable = phase("stable-anchor", 1000, function() entry.button:SetParent(entry.slot) end)
assert(
    stable.pointWrites == 0 and stable.hooks == 0,
    "parenting a collected button to its current slot does not rewrite anchors"
)

-- Dragging has a temporary OnUpdate; combat must cancel it immediately.
local launcher = ns.MinimapButton.GetFrame()
launcher.scripts.OnDragStart(launcher)
assert(launcher:GetScript("OnUpdate"))
TestUI.SetCombat(true)
ns.App.OnCombatStart()
assert(not launcher:GetScript("OnUpdate") and not ns.Window.GetFrame():IsShown())
TestUI.SetCombat(false)
ns.App.OnCombatEnd()
ns.Buttons.Sort = originalSort
TestUI.performance = results
