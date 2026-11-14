local frames = TestUI.frames
local function button(name, parent)
    local frame = CreateFrame("Button", name, parent or Minimap)
    frame.icon = true
    frame:SetSize(31, 29)
    frame:SetPoint("TOPLEFT", Minimap, "BOTTOMRIGHT", 13, -9)
    frame:SetPoint("BOTTOMRIGHT", Minimap, "CENTER", 7, 3)
    return frame
end
local clicked, hovered, dragged = 0, 0, 0
local alpha = button("LibDBIcon10_Alpha")
local hidden = button("LibDBIcon10_Hidden")
hidden:Hide()
local beta = button("BetaMinimapButton", MinimapBackdrop)
alpha:SetFrameStrata("MEDIUM")
alpha:SetFrameLevel(11)
beta:SetFrameStrata("HIGH")
beta:SetFrameLevel(23)
local native = button("MinimapZoomIn")
local plainNative = CreateFrame("Button", "PlainMinimapControl", Minimap)
local protected = button("ProtectedMinimapButton")
protected.protected = true
local late = button("LateMinimapButton")
local nestedNative = button("ArbitraryNativeChild", native)
alpha:SetScript("OnClick", function() clicked = clicked + 1 end)
alpha:SetScript("OnEnter", function() hovered = hovered + 1 end)
local drag = function() dragged = dragged + 1 end
alpha:SetScript("OnDragStart", drag)
alpha:SetScript("OnDragStop", drag)
local lib = {
    GetButtonList = function() return { "Alpha", "Hidden" } end,
    GetMinimapButton = function(_, name) return name == "Alpha" and alpha or hidden end,
}
LibStub = function(name) assert(name == "LibDBIcon-1.0"); return lib end

-- Malformed persisted settings must recover before any frame is positioned.
CompactAddonButtonsDB = { exceptions = false, position = { "INVALID", "CENTER", 0, 0 }, angle = 0/0, columns = false }
local legacySettings
if TEST_LEGACY then
    legacySettings = { exceptions = { ["lib:LegacyOnly"] = true }, angle = 131,
        position = { "TOP", "TOP", 15, -20 }, columns = 99 }
    BetterAddonButtonsDB, CompactAddonButtonsDB = legacySettings, nil
else
    -- Stale legacy data must never overwrite an already existing current database.
    BetterAddonButtonsDB = { angle = 17 }
end
local ns = {}
TestUI.ns = ns
for line in io.lines(ADDON_PATH .. "/CompactAddonButtons.toc") do
    if line:match("%.lua$") then assert(loadfile(ADDON_PATH .. "/" .. line))("CompactAddonButtons", ns) end
end
local events
for _, frame in ipairs(frames) do if frame.events.PLAYER_LOGIN then events = frame end end
local function fire(event, ...) events.scripts.OnEvent(events, event, ...) end
fire("ADDON_LOADED", "CompactAddonButtons")
local custom = button("UnusualButton", UIParent)
assert(CompactAddonButtons.RegisterButton("custom", "Custom", custom))
assert(not CompactAddonButtons.RegisterButton("custom", "Duplicate", button("UnusualDuplicate", UIParent)))
assert(not CompactAddonButtons.RegisterButton("different-key", "Duplicate", custom))
assert(not CompactAddonButtons.RegisterButton(nil, "Invalid", custom))
assert(not ns.App.IsReady(), "early registration must not create slots")
fire("PLAYER_LOGIN")
if TEST_LEGACY then
    assert(CompactAddonButtonsDB == legacySettings and CompactAddonButtonsDB.exceptions["lib:LegacyOnly"])
    assert(CompactAddonButtonsDB.angle == 131 and CompactAddonButtonsDB.position[1] == "TOP" and CompactAddonButtonsDB.position[3] == 15)
else
    assert(CompactAddonButtonsDB.angle == 220 and CompactAddonButtonsDB.position[1] == "CENTER")
end
assert(BetterAddonButtonsDB == nil and BetterAddonButtons == CompactAddonButtons)
assert(ns.Settings.GetColumns() == 6, "invalid or migrated columns must default to six")
assert(SLASH_COMPACTADDONBUTTONS1 == "/cab" and SLASH_COMPACTADDONBUTTONS3 == "/bab")
assert(#ns.Buttons.All() == 5, "discover LibDBIcon, fallback, backdrop, hidden, and custom buttons once")
assert(ns.Buttons.Find(alpha).key == "lib:Alpha")
assert(ns.Buttons.Find(beta).collected and ns.Buttons.Find(custom).collected)
assert(native:GetParent() == Minimap and protected:GetParent() == Minimap)
assert(not ns.Buttons.Find(nestedNative) and not ns.Buttons.Find(ns.MinimapButton.GetFrame()))
assert(not ns.Buttons.Find(plainNative), "a button without any icon is not an addon launcher")
assert(not ns.Window.GetFrame():IsShown() and not alpha:IsVisible())
assert(not hidden:IsShown(), "addon-hidden state must survive collection")
assert(alpha.width == 31 and alpha.height == 29, "original hit geometry is unchanged")
assert(alpha:GetScript("OnDragStart") == nil)

ns.App.Toggle(false)
assert(ns.Window.GetFrame():IsShown() and alpha:IsVisible())
assert(ns.Window.GetFrame():GetWidth() == 134 and ns.Window.GetFrame():GetHeight() == 38, "four buttons need only one compact row")
local popupPoint, popupRelative, popupRelativePoint, popupX = ns.Window.GetFrame():GetPoint()
assert(popupPoint == "BOTTOMLEFT" and popupRelative == ns.MinimapButton.GetFrame()
    and popupRelativePoint == "BOTTOMRIGHT" and popupX == 6, "popup must be next to the launcher")
ns.MinimapButton.GetFrame().centerX, ns.MinimapButton.GetFrame().centerY = 1800, 900
ns.Window.Refresh()
assert(ns.Window.GetFrame():GetPoint() == "TOPRIGHT", "upper-right launcher opens toward the screen interior")
ns.MinimapButton.GetFrame().centerX, ns.MinimapButton.GetFrame().centerY, ns.MinimapButton.GetFrame().scale = 950, 500, 2
ns.Window.Refresh()
assert(ns.Window.GetFrame():GetPoint() == "TOPRIGHT", "anchor selection respects effective UI scale")
ns.MinimapButton.GetFrame().centerX, ns.MinimapButton.GetFrame().centerY, ns.MinimapButton.GetFrame().scale = nil, nil, nil
assert(TestUI.MouseTarget(alpha) == alpha, "the popup panel must not intercept collected button input")
assert(TestUI.MouseTarget(beta) == beta and TestUI.MouseTarget(custom) == custom,
    "buttons with different original strata must remain clickable in the drawer")
TestUI.MouseTarget(alpha).scripts.OnClick(alpha, "RightButton")
TestUI.MouseTarget(alpha).scripts.OnEnter(alpha)
assert(clicked == 1 and hovered == 1, "real scripts must be preserved")
local slot = ns.Buttons.Find(alpha).slot
local unnecessaryHides = 0
slot:SetScript("OnHide", function() unnecessaryHides = unnecessaryHides + 1 end)
ns.App.Scan()
assert(unnecessaryHides == 0, "periodic scans must not flicker buttons or repeat hide callbacks")
alpha:SetPoint("CENTER", Minimap, "CENTER", 100, 100)
assert(alpha:GetNumPoints() == 1 and select(2, alpha:GetPoint()) == slot)
alpha:SetParent(Minimap)
assert(alpha:GetParent() == slot, "external positioning must not leak a collected button")

-- Settings mode contains every discovered entry, including exceptions and addon-hidden buttons.
ns.App.Toggle(true)
assert(ns.Window.GetFrame():IsShown() and not slot:IsShown())
assert(ns.Window.GetFrame():GetWidth() == 384 and ns.Window.GetFrame():GetHeight() == 432, "settings keep a readable layout")
assert(select(2, ns.Window.GetFrame():GetPoint()) == UIParent, "settings use their saved independent position")
local check
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" and frame.entry == ns.Buttons.Find(alpha) then check = frame end
end
assert(check and check:IsShown())
-- Reparenting and drawer layout can change a collected button's stacking order.
alpha:SetFrameStrata("BACKGROUND")
alpha:SetFrameLevel(0)
check:SetChecked(true)
check.scripts.OnClick(check)
assert(CompactAddonButtonsDB.exceptions["lib:Alpha"] and alpha:GetParent() == Minimap)
assert(alpha:GetFrameStrata() == "MEDIUM" and alpha:GetFrameLevel() == 11,
    "exceptions must regain their original stacking order immediately, without reloading")
assert(alpha:GetNumPoints() == 2)
local point, relative, relativePoint, x, y = alpha:GetPoint()
assert(point == "TOPLEFT" and relative == Minimap and relativePoint == "BOTTOMRIGHT" and x == 13 and y == -9)
assert(alpha:GetScript("OnDragStart") == drag and alpha:GetScript("OnDragStop") == drag)
alpha.scripts.OnDragStart(alpha)
assert(dragged == 1)
ns.App.Scan()
assert(#ns.Buttons.All() == 5 and alpha:GetParent() == Minimap, "repeat scans retain exceptions")
ns.App.SetException("lib:Alpha", false)
assert(alpha:GetParent() == slot)
alpha:SetFrameStrata("DIALOG")
alpha:SetFrameLevel(4)
beta:SetFrameStrata("BACKGROUND")
beta:SetFrameLevel(0)
ns.App.SetException("frame:BetaMinimapButton", true)
assert(beta:GetParent() == MinimapBackdrop and beta:GetFrameStrata() == "HIGH" and beta:GetFrameLevel() == 23,
    "backdrop buttons must retain their own strata and level")
ns.App.SetException("frame:BetaMinimapButton", false)
ns.App.Toggle(false)
assert(alpha:IsVisible())

-- Real addon visibility is respected without being overwritten on periodic updates.
alpha:Hide()
ns.App.Scan()
assert(not alpha:IsShown() and not slot:IsShown())
alpha:Show()
ns.App.Scan()
assert(slot:IsShown())

TestUI.SetCombat(true)
fire("PLAYER_REGEN_DISABLED")
assert(not ns.Window.GetFrame():IsShown())
ns.App.SetException("lib:Alpha", true)
assert(ns.App.IsPending() and alpha:GetParent() == slot, "combat must defer reparenting")
ns.App.Toggle(false)
assert(not ns.Window.GetFrame():IsShown())
local afterLogin = button("AfterLoginMinimapButton")
ns.App.Scan()
assert(not ns.Buttons.Find(afterLogin), "no scanning or moving UI during combat")
TestUI.SetCombat(false)
fire("PLAYER_REGEN_ENABLED")
assert(not ns.App.IsPending() and alpha:GetParent() == Minimap)
assert(alpha:GetFrameStrata() == "MEDIUM" and alpha:GetFrameLevel() == 11,
    "repeated collection and combat-deferred release must restore stacking order")
assert(ns.Buttons.Find(afterLogin).collected)

-- LibDBIcon can become available after a fallback button has already been collected.
ns.App.SetException("frame:LateMinimapButton", true)
lib.GetButtonList = function() return { "Alpha", "Hidden", "Late" } end
lib.GetMinimapButton = function(_, name)
    if name == "Alpha" then return alpha elseif name == "Hidden" then return hidden else return late end
end
ns.App.Scan()
assert(ns.Buttons.Find(late).key == "lib:Late" and CompactAddonButtonsDB.exceptions["lib:Late"])
assert(late:GetParent() == Minimap and not CompactAddonButtonsDB.exceptions["frame:LateMinimapButton"])
assert(#ns.Buttons.All() == 6, "late library discovery must not duplicate entries")

-- Slash commands, saved drag position, filtered views, and Escape handling are wired.
SlashCmdList.COMPACTADDONBUTTONS("settings")
assert(ns.Window.GetFrame():IsShown())
local search, header
for _, frame in ipairs(frames) do
    if frame.kind == "EditBox" then search = frame end
    if frame.parent == ns.Window.GetFrame() and frame.scripts.OnDragStop then header = frame end
end
search:SetText("no-such-addon")
search.scripts.OnTextChanged(search)
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" then assert(not frame:IsShown()) end
end
ns.App.Toggle(false)
assert(ns.Window.GetFrame():IsShown() and ns.Buttons.Find(beta).slot:IsShown(), "settings search must not filter the popup")
assert(not search:IsShown(), "popup contains only addon icons")
ns.App.Toggle(true)
search:SetText("")
search.scripts.OnTextChanged(search)
ns.Window.GetFrame():ClearAllPoints()
ns.Window.GetFrame():SetPoint("TOP", UIParent, "TOP", 15, -20)
header.scripts.OnDragStop(header)
assert(CompactAddonButtonsDB.position[1] == "TOP" and CompactAddonButtonsDB.position[3] == 15)
search.scripts.OnEscapePressed(search)
assert(not ns.Window.GetFrame():IsShown())
assert(UISpecialFrames[1] == "CompactAddonButtonsWindow")

-- Exceptions are honored at initial collection, as after a reload.
local persisted = button("PersistedMinimapButton")
CompactAddonButtonsDB.exceptions["frame:PersistedMinimapButton"] = true
events.scripts.OnUpdate(events, 3)
assert(ns.Buttons.Find(persisted) and not ns.Buttons.Find(persisted).collected)
assert(persisted:GetParent() == Minimap)

local textured = CreateFrame("Button", "TextureOnlyMinimapButton", Minimap)
textured.regions = { CreateFrame("Texture", nil, textured) }
ns.App.Scan()
assert(ns.Buttons.Find(textured).collected, "detect texture-only custom minimap buttons")

GetMinimapShape = function() return "SQUARE" end
CompactAddonButtonsDB.angle = 45
ns.MinimapButton.Position()
local _, _, _, launcherX, launcherY = ns.MinimapButton.GetFrame():GetPoint()
assert(math.abs(launcherX - 57) < 0.01 and math.abs(launcherY - 57) < 0.01)

-- A large addon collection expands into full rows without a scroll frame.
for i = 1, 35 do button("Extra" .. i .. "MinimapButton") end
ns.App.Scan()
ns.App.Toggle(false)
local popupScroll = CompactAddonButtonsScroll
local grid = ns.Buttons.Find(beta).slot:GetParent()
assert(grid:GetParent() == ns.Window.GetFrame() and grid:IsShown() and not popupScroll:IsShown())
assert(grid:GetWidth() == 192 and grid:GetHeight() > 192)
assert(ns.Window.GetFrame():GetWidth() == 198 and ns.Window.GetFrame():GetHeight() == grid:GetHeight() + 6)

-- The actual settings menu controls saved columns and wrapping without scrolling.
local visible = {}
for _, entry in ipairs(ns.Buttons.All()) do
    if entry.collected and entry.button:IsShown() then visible[#visible + 1] = entry end
end
ns.App.Toggle(true)
local columnsDropdown = CompactAddonButtonsColumns
assert(columnsDropdown:IsShown() and #columnsDropdown.choices == 12 and columnsDropdown.selectedText == "6")
assert(popupScroll:IsShown() and not grid:IsShown(), "only settings use the scroll frame")
popupScroll:SetVerticalScroll(75)
for value = 1, 12 do
    local choice = columnsDropdown.choices[value]
    assert(choice.value == value)
    choice.choose(choice.value)
    assert(ns.Settings.GetColumns() == value and CompactAddonButtonsDB.columns == value)
    assert(columnsDropdown.selectedText == tostring(value))
    ns.App.Toggle(false)
    assert(not columnsDropdown:IsShown(), "grid controls belong only in settings")
    local rowCount = math.ceil(#visible / value)
    assert(ns.Window.GetFrame():GetWidth() == value * 32 + 6)
    assert(ns.Window.GetFrame():GetHeight() == rowCount * 32 + 6)
    assert(grid:IsShown() and not popupScroll:IsShown() and popupScroll:GetVerticalScroll() == 0)
    assert(grid:GetHeight() == rowCount * 32, "all rows must fit without clipping")
    for i, entry in ipairs(visible) do
        local _, x, y = entry.slot:GetPoint()
        assert(x == ((i - 1) % value) * 32 and y == -math.floor((i - 1) / value) * 32,
            "changing columns must reflow every visible button")
    end
    ns.App.Toggle(true)
end
ns.Settings.Initialize()
assert(ns.Settings.GetColumns() == 12, "columns must survive saved-settings initialization")
for _, invalid in ipairs({ false, "4", 0, 13, 1.5, 0/0, math.huge }) do
    assert(not ns.App.SetColumns(invalid) and ns.Settings.GetColumns() == 12)
end
assert(not ns.App.SetColumns(nil))
TestUI.SetCombat(true)
fire("PLAYER_REGEN_DISABLED")
columnsDropdown.choices[2].choose(2)
assert(ns.Settings.GetColumns() == 2 and ns.App.IsPending())
assert(not ns.Window.GetFrame():IsShown())
TestUI.SetCombat(false)
fire("PLAYER_REGEN_ENABLED")
assert(not ns.App.IsPending() and columnsDropdown.selectedText == "2")
ns.App.Toggle(false)
assert(ns.Window.GetFrame():GetWidth() == 70, "combat-deferred columns apply after combat")
assert(ns.App.SetColumns(6))

-- An empty popup remains small and contains a useful empty-state message.
for _, entry in ipairs(ns.Buttons.All()) do ns.App.SetException(entry.key, true) end
assert(ns.Window.GetFrame():GetWidth() == 210 and ns.Window.GetFrame():GetHeight() == 38)
