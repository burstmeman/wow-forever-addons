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
alpha.icon = alpha:CreateTexture()
alpha.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
alpha.icon:SetTexCoord(0.1, 0.2, 0.1, 0.8, 0.9, 0.2, 0.9, 0.8)
local hidden = button("LibDBIcon10_Hidden")
hidden:Hide()
local beta = button("BetaMinimapButton", MinimapBackdrop)
alpha:SetFrameStrata("MEDIUM")
alpha:SetFrameLevel(11)
alpha:SetFixedFrameStrata(true)
alpha:SetFixedFrameLevel(true)
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
LibStub = function(name)
    assert(name == "LibDBIcon-1.0")
    return lib
end

-- Malformed persisted settings must recover before any frame is positioned.
CompactAddonButtonsDB = { exceptions = false, position = { "INVALID", "CENTER", 0, 0 }, angle = 0 / 0, columns = false }
local legacySettings
if TEST_LEGACY then
    legacySettings = {
        exceptions = { ["lib:LegacyOnly"] = true },
        angle = 131,
        position = { "TOP", "TOP", 15, -20 },
        columns = 99,
    }
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
for _, frame in ipairs(frames) do
    if frame.events.PLAYER_LOGIN then events = frame end
end
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
    assert(
        CompactAddonButtonsDB.angle == 131
            and CompactAddonButtonsDB.position[1] == "TOP"
            and CompactAddonButtonsDB.position[3] == 15
    )
else
    assert(CompactAddonButtonsDB.angle == 220 and CompactAddonButtonsDB.position[1] == "CENTER")
end
assert(BetterAddonButtonsDB == nil and BetterAddonButtons == CompactAddonButtons)
assert(ns.Settings.GetColumns() == 6, "invalid or migrated columns must default to six")
assert(not ns.Settings.GetPopupManual(), "the button window follows the screen until placement is chosen")
assert(
    ns.Settings.GetPopupAnchor() == "LEFT" and ns.Settings.GetPopupOffsetX() == 0 and ns.Settings.GetPopupOffsetY() == 0,
    "manual placement starts on the left, six pixels from the launcher"
)
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
assert(
    not alpha:HasFixedFrameStrata() and not alpha:HasFixedFrameLevel(),
    "LibDBIcon fixed minimap layering must be suspended inside the drawer"
)

ns.App.Toggle(false)
assert(ns.Window.GetFrame():IsShown() and alpha:IsVisible())
local alphaSlot = ns.Buttons.Find(alpha).slot
local alphaGrid = alphaSlot:GetParent()
assert(
    alphaGrid:GetFrameStrata() == ns.Window.GetFrame():GetFrameStrata()
        and alphaSlot:GetFrameStrata() == alphaGrid:GetFrameStrata()
        and alpha:GetFrameStrata() == alphaGrid:GetFrameStrata(),
    "the entire icon hierarchy must be above the dialog backdrop without implicit strata inheritance"
)
assert(
    alphaGrid:GetFrameLevel() > ns.Window.GetFrame():GetFrameLevel()
        and alphaSlot:GetFrameLevel() > alphaGrid:GetFrameLevel()
        and alpha:GetFrameLevel() > alphaSlot:GetFrameLevel()
)
assert(
    ns.Window.GetFrame():GetWidth() == 134 and ns.Window.GetFrame():GetHeight() == 38,
    "four buttons need only one compact row"
)
local popupPoint, popupRelative, popupRelativePoint, popupX = ns.Window.GetFrame():GetPoint()
assert(
    popupPoint == "BOTTOMLEFT"
        and popupRelative == ns.MinimapButton.GetFrame()
        and popupRelativePoint == "BOTTOMRIGHT"
        and popupX == 6,
    "popup must be next to the launcher"
)
ns.MinimapButton.GetFrame().centerX, ns.MinimapButton.GetFrame().centerY = 1800, 900
ns.Window.Refresh()
assert(ns.Window.GetFrame():GetPoint() == "TOPRIGHT", "upper-right launcher opens toward the screen interior")
ns.MinimapButton.GetFrame().centerX, ns.MinimapButton.GetFrame().centerY, ns.MinimapButton.GetFrame().scale =
    950, 500, 2
ns.Window.Refresh()
assert(ns.Window.GetFrame():GetPoint() == "TOPRIGHT", "anchor selection respects effective UI scale")
ns.MinimapButton.GetFrame().centerX, ns.MinimapButton.GetFrame().centerY, ns.MinimapButton.GetFrame().scale =
    nil, nil, nil
ns.Window.Refresh()
assert(ns.Window.GetFrame():GetPoint() == "BOTTOMLEFT", "clearing the launcher position restores the near side")
assert(ns.App.SetPopup("RIGHT", 12, -5) and ns.Window.GetFrame():GetPoint() == "BOTTOMLEFT")
assert(ns.App.SetPopupManual(true))
local rightPoint, rightRelative, rightRelativePoint, rightX, rightY = ns.Window.GetFrame():GetPoint()
assert(
    rightPoint == "LEFT"
        and rightRelative == ns.MinimapButton.GetFrame()
        and rightRelativePoint == "RIGHT"
        and rightX == 18
        and rightY == -5,
    "manual placement can put the window to the right of the launcher"
)
local edgePoint, edgeRelative, edgeX, edgeY = ns.Window.PopupPoint("LEFT", -255, 256)
assert(edgePoint == "RIGHT" and edgeRelative == "LEFT" and edgeX == -261 and edgeY == 256)
assert(not ns.App.SetPopup("CENTER", 4) and ns.Settings.GetPopupAnchor() == "RIGHT")
assert(not ns.App.SetPopup("LEFT", -256) and ns.Settings.GetPopupOffsetX() == 12)
assert(ns.App.SetPopupManual(false) and ns.Window.GetFrame():GetPoint() == "BOTTOMLEFT")
assert(ns.App.SetPopup("LEFT", 0, 0))
assert(TestUI.MouseTarget(alpha) == alpha, "the popup panel must not intercept collected button input")
assert(
    TestUI.MouseTarget(beta) == beta and TestUI.MouseTarget(custom) == custom,
    "buttons with different original strata must remain clickable in the drawer"
)
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
assert(ns.Window.GetFrame():IsShown() and slot:IsShown() and ns.Window.GetPopupFrame():IsVisible())
assert(TestUI.MouseTarget(alpha) == alpha, "preview backdrop must not intercept button clicks")
assert(
    ns.Window.GetFrame():GetWidth() == 780 and ns.Window.GetFrame():GetHeight() == 540,
    "settings keep a readable layout"
)
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
assert(
    alpha:HasFixedFrameStrata() and alpha:HasFixedFrameLevel(),
    "excluding a button must restore its original fixed-layer flags"
)
assert(
    alpha:GetFrameStrata() == "MEDIUM" and alpha:GetFrameLevel() == 11,
    "exceptions must regain their original stacking order immediately, without reloading"
)
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
assert(
    beta:GetParent() == MinimapBackdrop and beta:GetFrameStrata() == "HIGH" and beta:GetFrameLevel() == 23,
    "backdrop buttons must retain their own strata and level"
)
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
assert(
    alpha:GetFrameStrata() == "MEDIUM" and alpha:GetFrameLevel() == 11,
    "repeated collection and combat-deferred release must restore stacking order"
)
assert(ns.Buttons.Find(afterLogin).collected)

-- LibDBIcon can become available after a fallback button has already been collected.
ns.App.SetException("frame:LateMinimapButton", true)
lib.GetButtonList = function() return { "Alpha", "Hidden", "Late" } end
lib.GetMinimapButton = function(_, name)
    if name == "Alpha" then
        return alpha
    elseif name == "Hidden" then
        return hidden
    else
        return late
    end
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
    if frame.kind == "EditBox" and frame.hint then search = frame end
    if frame.parent == ns.Window.GetFrame() and frame.scripts.OnDragStop then header = frame end
end
search:SetText("no-such-addon")
search.scripts.OnTextChanged(search)
assert(
    ns.Window.GetPopupFrame():IsVisible() and ns.Buttons.Find(beta).slot:IsShown(),
    "search does not filter the live preview"
)
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" and frame ~= CompactAddonButtonsPopupManual then assert(not frame:IsShown()) end
end
ns.App.Toggle(false)
assert(
    ns.Window.GetFrame():IsShown() and ns.Buttons.Find(beta).slot:IsShown(),
    "settings search must not filter the popup"
)
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
for i = 1, 35 do
    button("Extra" .. i .. "MinimapButton")
end
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
local iconRow
for _, frame in ipairs(frames) do
    if frame.entry and frame.entry.button == alpha and frame.icon then iconRow = frame end
end
assert(iconRow and iconRow.icon ~= alpha.icon, "settings copy the icon without taking ownership")
assert(iconRow.icon:GetTexture() == alpha.icon:GetTexture())
assert(table.concat({ iconRow.icon:GetTexCoord() }, ",") == table.concat({ alpha.icon:GetTexCoord() }, ","))
assert(alpha.icon:GetParent() == alpha, "source icon remains attached to its button")
assert(TestUI.MouseTarget(iconRow) == iconRow, "list rows receive input above the window background")
alpha.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
ns.Window.Refresh()
assert(iconRow.icon:GetTexture() == alpha.icon:GetTexture(), "icon changes update without a layout change")
local originalIcon = alpha.icon
alpha.icon, alpha.Icon = nil, originalIcon
ns.Window.Refresh()
assert(iconRow.icon:GetTexture() == originalIcon:GetTexture(), "capitalized icon field works without lowercase icon")
alpha.Icon, alpha.texture = nil, originalIcon
ns.Window.Refresh()
assert(iconRow.icon:GetTexture() == originalIcon:GetTexture(), "normal texture works without icon fields")
alpha.texture, alpha.regions = nil, { originalIcon }
ns.Window.Refresh()
assert(iconRow.icon:GetTexture() == originalIcon:GetTexture(), "custom texture regions are supported")
alpha.regions = {}
ns.Window.Refresh()
assert(iconRow.icon:GetTexture() == "Interface\\Icons\\INV_Misc_QuestionMark", "iconless buttons have a placeholder")
alpha.icon = originalIcon
ns.Window.Refresh()
local generalBlock = CompactAddonButtonsLanguage:GetParent()
local buttonsBlock = popupScroll:GetParent()
local _, listX = buttonsBlock:GetPoint()
local _, controlsX = generalBlock:GetPoint()
assert(listX > controlsX + generalBlock:GetWidth(), "button list sits to the right of the controls")
assert(buttonsBlock:GetHeight() >= 400, "settings give the button list most of the window height")
local manualCheck = CompactAddonButtonsPopupManual
assert(CompactAddonButtonsPopupAnchor == nil, "side selector is no longer created")
assert(manualCheck:IsShown() and not manualCheck:GetChecked())
manualCheck:SetChecked(true)
manualCheck.scripts.OnClick(manualCheck)
assert(ns.Settings.GetPopupManual())
local sliders = {}
for _, frame in ipairs(frames) do
    if frame.kind == "Slider" then sliders[frame.axis] = frame end
end
assert(sliders.X and sliders.Y and sliders.X:GetParent() == manualCheck:GetParent())
assert(CompactAddonButtonsLanguage:GetParent() == CompactAddonButtonsColumns:GetParent())
assert(CompactAddonButtonsLanguage:GetParent() ~= manualCheck:GetParent(), "settings use explicit sections")
for _, slider in pairs(sliders) do
    local minimum, maximum = slider:GetMinMaxValues()
    assert(minimum == -255 and maximum == 256 and slider.step == 1 and slider:IsEnabled())
    assert(slider:IsMouseEnabled() and slider:GetScript("OnValueChanged"), "axis sliders receive user input")
    assert(TestUI.MouseTarget(slider) == slider, "settings backgrounds must not cover slider input")
    assert(slider.label:GetJustifyH() == "LEFT")
end
-- Existing saved sides remain valid even though the selector is gone.
assert(ns.App.SetPopup("TOP", nil, nil))
sliders.X:SetValue(-255)
sliders.Y:SetValue(256)
assert(ns.Settings.GetPopupOffsetX() == -255 and ns.Settings.GetPopupOffsetY() == 256)
sliders.X:SetValue(-40.2)
sliders.Y:SetValue(30)
assert(ns.Settings.GetPopupOffsetX() == -40 and ns.Settings.GetPopupOffsetY() == 30)
for _, invalid in ipairs({ -256, 257, 1.5, false, "10", 0 / 0, math.huge }) do
    assert(not ns.App.SetPopup(nil, invalid, nil) and not ns.App.SetPopup(nil, nil, invalid))
end
assert(not ns.App.SetPopup("TOPLEFT", 0, 0), "diagonals are no longer selectable")
local livePopup = ns.Window.GetPopupFrame()
assert(livePopup ~= ns.Window.GetFrame() and livePopup:IsVisible())
local livePoint, liveLauncher, liveRelative, liveX, liveY = livePopup:GetPoint()
assert(livePoint == "BOTTOM" and liveLauncher == ns.MinimapButton.GetFrame())
assert(liveRelative == "TOP" and liveX == -40 and liveY == 36, "axis sliders update the live preview immediately")
assert(select(2, ns.Window.GetFrame():GetPoint()) == UIParent, "preview placement must not move settings")
ns.Window.Close()
assert(not livePopup:IsShown() and not ns.Window.GetFrame():IsShown(), "closing settings closes the preview")
ns.App.Toggle(true)
assert(ns.Window.GetPopupFrame() == livePopup and livePopup:IsVisible(), "reopening reuses the preview")
ns.App.Toggle(false)
local abovePoint, _, aboveRelativePoint, aboveX, aboveY = ns.Window.GetFrame():GetPoint()
assert(
    abovePoint == "BOTTOM" and aboveRelativePoint == "TOP" and aboveX == -40 and aboveY == 36,
    "saved side and offset place the open window"
)
assert(ns.App.SetPopupManual(false))
assert(ns.App.SetPopup("LEFT", 0, 0))
ns.App.Toggle(true)
local columnsDropdown = CompactAddonButtonsColumns
assert(columnsDropdown:IsShown() and #columnsDropdown.choices == 12 and columnsDropdown.selectedText == "6")
assert(popupScroll:IsShown() and grid:IsVisible(), "settings show the list alongside the live icon preview")
assert(grid:GetParent() == ns.Window.GetPopupFrame())
popupScroll:SetVerticalScroll(75)
for value = 1, 12 do
    local choice = columnsDropdown.choices[value]
    assert(choice.value == value)
    choice.choose(choice.value)
    assert(ns.Settings.GetColumns() == value and CompactAddonButtonsDB.columns == value)
    assert(columnsDropdown.selectedText == tostring(value))
    local liveRows = math.ceil(#visible / value)
    assert(ns.Window.GetPopupFrame():GetWidth() == value * 32 + 6)
    assert(ns.Window.GetPopupFrame():GetHeight() == liveRows * 32 + 6)
    assert(ns.Window.GetFrame():GetWidth() == 780, "live preview must not resize configuration")
    ns.App.Toggle(false)
    assert(not columnsDropdown:IsShown(), "grid controls belong only in settings")
    local rowCount = math.ceil(#visible / value)
    assert(ns.Window.GetFrame():GetWidth() == value * 32 + 6)
    assert(ns.Window.GetFrame():GetHeight() == rowCount * 32 + 6)
    assert(grid:IsShown() and not popupScroll:IsShown() and popupScroll:GetVerticalScroll() == 0)
    assert(grid:GetHeight() == rowCount * 32, "all rows must fit without clipping")
    for i, entry in ipairs(visible) do
        local _, x, y = entry.slot:GetPoint()
        assert(
            x == ((i - 1) % value) * 32 and y == -math.floor((i - 1) / value) * 32,
            "changing columns must reflow every visible button"
        )
    end
    ns.App.Toggle(true)
end
CompactAddonButtonsDB.popupManual = "yes"
CompactAddonButtonsDB.popupAnchor = "CENTER"
CompactAddonButtonsDB.popupOffset = false
CompactAddonButtonsDB.popupOffsetX = false
CompactAddonButtonsDB.popupOffsetY = math.huge
ns.Settings.Initialize()
assert(ns.Settings.GetColumns() == 12, "columns must survive saved-settings initialization")
assert(
    not ns.Settings.GetPopupManual()
        and ns.Settings.GetPopupAnchor() == "LEFT"
        and ns.Settings.GetPopupOffsetX() == 0
        and ns.Settings.GetPopupOffsetY() == 0,
    "a malformed window placement recovers to automatic placement"
)
for _, invalid in ipairs({ false, "4", 0, 13, 1.5, 0 / 0, math.huge }) do
    assert(not ns.App.SetColumns(invalid) and ns.Settings.GetColumns() == 12)
end
assert(not ns.App.SetColumns(nil))
TestUI.SetCombat(true)
fire("PLAYER_REGEN_DISABLED")
columnsDropdown.choices[2].choose(2)
assert(ns.Settings.GetColumns() == 2 and ns.App.IsPending())
assert(not ns.Window.GetFrame():IsShown())
assert(not livePopup:IsVisible(), "combat closes settings and their live preview")
TestUI.SetCombat(false)
fire("PLAYER_REGEN_ENABLED")
assert(not ns.App.IsPending() and columnsDropdown.selectedText == "2")
ns.App.Toggle(false)
assert(ns.Window.GetFrame():GetWidth() == 70, "combat-deferred columns apply after combat")
assert(ns.App.SetColumns(6))

-- An empty popup remains small and contains a useful empty-state message.
for _, entry in ipairs(ns.Buttons.All()) do
    ns.App.SetException(entry.key, true)
end
assert(ns.Window.GetFrame():GetWidth() == 210 and ns.Window.GetFrame():GetHeight() == 38)
