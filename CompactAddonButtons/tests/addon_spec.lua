local combat, frames = false, {}
local methods = {}
local function noop() end
for _, method in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetFrameStrata",
    "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "SetFrameLevel",
    "RegisterForClicks", "SetHighlightTexture", "SetTexture", "SetTexCoord", "SetJustifyH",
    "SetHitRectInsets", "SetTextColor", "SetAutoFocus", "SetMaxLetters", "SetOwner", "AddLine",
    "StartMoving", "StopMovingOrSizing" }) do methods[method] = noop end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:GetChildren()
    local result = {}
    for _, frame in ipairs(frames) do if frame.parent == self then result[#result + 1] = frame end end
    return unpack(result)
end
function methods:IsObjectType(kind) return self.kind == kind or kind == "Frame" end
function methods:IsProtected() return self.protected end
function methods:SetParent(parent) self.parent = parent end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function methods:GetNumPoints() return #self.points end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetCenter() return self.centerX or 200, self.centerY or 200 end
function methods:GetNormalTexture() return self.texture end
function methods:GetRegions() return unpack(self.regions or {}) end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:Show() self.shown = true end
function methods:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetText(value) self.value = value end
function methods:GetText() return self.value or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:ClearFocus() self.focus = false end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetScrollChild(child) self.child = child end

function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, points = {},
        scripts = {}, events = {}, shown = true, width = 100, height = 100 }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
GetLocale = function() return TEST_LOCALE end
InCombatLockdown = function() return combat end
tinsert = table.insert
UISpecialFrames, SlashCmdList = {}, {}
UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
MinimapBackdrop = CreateFrame("Frame", "MinimapBackdrop", UIParent)
GameTooltip = CreateFrame("Frame", "GameTooltip", UIParent)
GetCursorPosition = function() return 250, 200 end
math.atan2 = math.atan2 or function(y, x) return math.atan(y / x) end

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
CompactAddonButtonsDB = { exceptions = false, position = { "INVALID", "CENTER", 0, 0 }, angle = 0/0 }
local legacySettings
if TEST_LEGACY then
    legacySettings = { exceptions = { ["lib:LegacyOnly"] = true }, angle = 131,
        position = { "TOP", "TOP", 15, -20 } }
    BetterAddonButtonsDB, CompactAddonButtonsDB = legacySettings, nil
else
    -- Stale legacy data must never overwrite an already existing current database.
    BetterAddonButtonsDB = { angle = 17 }
end
local ns = {}
for line in io.lines(ADDON_PATH .. "/CompactAddonButtons.toc") do
    if line:match("%.lua$") then assert(loadfile(ADDON_PATH .. "/" .. line))("CompactAddonButtons", ns) end
end
local events
for _, frame in ipairs(frames) do if frame.events.PLAYER_LOGIN then events = frame end end
local function fire(event, ...) events.scripts.OnEvent(events, event, ...) end
fire("ADDON_LOADED", "CompactAddonButtons")
local custom = button("UnusualButton", UIParent)
assert(CompactAddonButtons.RegisterButton("custom", "Custom", custom))
assert(not CompactAddonButtons.RegisterButton(nil, "Invalid", custom))
assert(not ns.uiReady, "early registration must not create slots")
fire("PLAYER_LOGIN")
if TEST_LEGACY then
    assert(ns.db == legacySettings and ns.db.exceptions["lib:LegacyOnly"])
    assert(ns.db.angle == 131 and ns.db.position[1] == "TOP" and ns.db.position[3] == 15)
else
    assert(ns.db.angle == 220 and ns.db.position[1] == "CENTER")
end
assert(BetterAddonButtonsDB == nil and BetterAddonButtons == CompactAddonButtons)
assert(SLASH_COMPACTADDONBUTTONS1 == "/cab" and SLASH_COMPACTADDONBUTTONS3 == "/bab")
assert(#ns.entries == 5, "discover LibDBIcon, fallback, backdrop, hidden, and custom buttons once")
assert(ns.byButton[alpha].key == "lib:Alpha")
assert(ns.byButton[beta].collected and ns.byButton[custom].collected)
assert(native:GetParent() == Minimap and protected:GetParent() == Minimap)
assert(not ns.byButton[nestedNative] and not ns.byButton[ns.launcher])
assert(not ns.byButton[plainNative], "a button without any icon is not an addon launcher")
assert(not ns.panel:IsShown() and not alpha:IsVisible())
assert(not hidden:IsShown(), "addon-hidden state must survive collection")
assert(alpha.width == 31 and alpha.height == 29, "original hit geometry is unchanged")
assert(alpha:GetScript("OnDragStart") == nil)

ns.Toggle(false)
assert(ns.panel:IsShown() and alpha:IsVisible())
assert(ns.panel:GetWidth() == 192 and ns.panel:GetHeight() == 60, "four buttons need only one compact row")
local popupPoint, popupRelative, popupRelativePoint, popupX = ns.panel:GetPoint()
assert(popupPoint == "BOTTOMLEFT" and popupRelative == ns.launcher
    and popupRelativePoint == "BOTTOMRIGHT" and popupX == 6, "popup must be next to the launcher")
ns.launcher.centerX, ns.launcher.centerY = 1800, 900
ns.RefreshUI()
assert(ns.panel:GetPoint() == "TOPRIGHT", "upper-right launcher opens toward the screen interior")
ns.launcher.centerX, ns.launcher.centerY, ns.launcher.scale = 950, 500, 2
ns.RefreshUI()
assert(ns.panel:GetPoint() == "TOPRIGHT", "anchor selection respects effective UI scale")
ns.launcher.centerX, ns.launcher.centerY, ns.launcher.scale = nil, nil, nil
alpha.scripts.OnClick(alpha, "RightButton")
alpha.scripts.OnEnter(alpha)
assert(clicked == 1 and hovered == 1, "real scripts must be preserved")
local slot = ns.byButton[alpha].slot
local unnecessaryHides = 0
slot:SetScript("OnHide", function() unnecessaryHides = unnecessaryHides + 1 end)
ns.Scan()
assert(unnecessaryHides == 0, "periodic scans must not flicker buttons or repeat hide callbacks")
alpha:SetPoint("CENTER", Minimap, "CENTER", 100, 100)
assert(alpha:GetNumPoints() == 1 and select(2, alpha:GetPoint()) == slot)
alpha:SetParent(Minimap)
assert(alpha:GetParent() == slot, "external positioning must not leak a collected button")

-- Settings mode contains every discovered entry, including exceptions and addon-hidden buttons.
ns.Toggle(true)
assert(ns.panel:IsShown() and not slot:IsShown())
assert(ns.panel:GetWidth() == 384 and ns.panel:GetHeight() == 350, "settings keep a readable layout")
assert(select(2, ns.panel:GetPoint()) == UIParent, "settings use their saved independent position")
local check
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" and frame.entry == ns.byButton[alpha] then check = frame end
end
assert(check and check:IsShown())
check:SetChecked(true)
check.scripts.OnClick(check)
assert(ns.db.exceptions["lib:Alpha"] and alpha:GetParent() == Minimap)
assert(alpha:GetNumPoints() == 2)
local point, relative, relativePoint, x, y = alpha:GetPoint()
assert(point == "TOPLEFT" and relative == Minimap and relativePoint == "BOTTOMRIGHT" and x == 13 and y == -9)
assert(alpha:GetScript("OnDragStart") == drag and alpha:GetScript("OnDragStop") == drag)
alpha.scripts.OnDragStart(alpha)
assert(dragged == 1)
ns.Scan()
assert(#ns.entries == 5 and alpha:GetParent() == Minimap, "repeat scans retain exceptions")
ns.SetException("lib:Alpha", false)
assert(alpha:GetParent() == slot)
ns.Toggle(false)
assert(alpha:IsVisible())

-- Real addon visibility is respected without being overwritten on periodic updates.
alpha:Hide()
ns.Scan()
assert(not alpha:IsShown() and not slot:IsShown())
alpha:Show()
ns.Scan()
assert(slot:IsShown())

combat = true
fire("PLAYER_REGEN_DISABLED")
assert(not ns.panel:IsShown())
ns.SetException("lib:Alpha", true)
assert(ns.pending and alpha:GetParent() == slot, "combat must defer reparenting")
ns.Toggle(false)
assert(not ns.panel:IsShown())
local afterLogin = button("AfterLoginMinimapButton")
ns.Scan()
assert(not ns.byButton[afterLogin], "no scanning or moving UI during combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(not ns.pending and alpha:GetParent() == Minimap)
assert(ns.byButton[afterLogin].collected)

-- LibDBIcon can become available after a fallback button has already been collected.
ns.SetException("frame:LateMinimapButton", true)
lib.GetButtonList = function() return { "Alpha", "Hidden", "Late" } end
lib.GetMinimapButton = function(_, name)
    if name == "Alpha" then return alpha elseif name == "Hidden" then return hidden else return late end
end
ns.Scan()
assert(ns.byButton[late].key == "lib:Late" and ns.db.exceptions["lib:Late"])
assert(late:GetParent() == Minimap and not ns.db.exceptions["frame:LateMinimapButton"])
assert(#ns.entries == 6, "late library discovery must not duplicate entries")

-- Slash commands, saved drag position, filtered views, and Escape handling are wired.
SlashCmdList.COMPACTADDONBUTTONS("settings")
assert(ns.panel:IsShown())
local search, header
for _, frame in ipairs(frames) do
    if frame.kind == "EditBox" then search = frame end
    if frame.parent == ns.panel and frame.scripts.OnDragStop then header = frame end
end
search:SetText("no-such-addon")
search.scripts.OnTextChanged(search)
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" then assert(not frame:IsShown()) end
end
ns.Toggle(false)
assert(ns.panel:IsShown() and ns.byButton[beta].slot:IsShown(), "settings search must not filter the popup")
assert(not search:IsShown(), "popup contains only addon icons")
ns.Toggle(true)
search:SetText("")
search.scripts.OnTextChanged(search)
ns.panel:ClearAllPoints()
ns.panel:SetPoint("TOP", UIParent, "TOP", 15, -20)
header.scripts.OnDragStop(header)
assert(ns.db.position[1] == "TOP" and ns.db.position[3] == 15)
search.scripts.OnEscapePressed(search)
assert(not ns.panel:IsShown())
assert(UISpecialFrames[1] == "CompactAddonButtonsWindow")

-- Exceptions are honored at initial collection, as after a reload.
local persisted = button("PersistedMinimapButton")
ns.db.exceptions["frame:PersistedMinimapButton"] = true
events.scripts.OnUpdate(events, 3)
assert(ns.byButton[persisted] and not ns.byButton[persisted].collected)
assert(persisted:GetParent() == Minimap)

local textured = CreateFrame("Button", "TextureOnlyMinimapButton", Minimap)
textured.regions = { CreateFrame("Texture", nil, textured) }
ns.Scan()
assert(ns.byButton[textured].collected, "detect texture-only custom minimap buttons")

GetMinimapShape = function() return "SQUARE" end
ns.db.angle = 45
ns.PositionLauncher()
local _, _, _, launcherX, launcherY = ns.launcher:GetPoint()
assert(math.abs(launcherX - 57) < 0.01 and math.abs(launcherY - 57) < 0.01)

-- A large addon collection scrolls instead of creating a screen-sized popup.
for i = 1, 35 do button("Extra" .. i .. "MinimapButton") end
ns.Scan()
ns.Toggle(false)
assert(ns.panel:GetWidth() == 256 and ns.panel:GetHeight() == 280)
local popupScroll = CompactAddonButtonsScroll
assert(popupScroll.child:GetHeight() > 264)

-- An empty popup remains small and contains a useful empty-state message.
for _, entry in ipairs(ns.entries) do ns.SetException(entry.key, true) end
assert(ns.panel:GetWidth() == 210 and ns.panel:GetHeight() == 60)
