local addonName, ns = ...
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
local ready, elapsed = false, 0

local function defaults()
    -- The previous addon name used this saved variable. Migrate only once, and
    -- prefer the current settings if both versions have persisted data.
    if type(CompactAddonButtonsDB) ~= "table" and type(BetterAddonButtonsDB) == "table" then
        CompactAddonButtonsDB = BetterAddonButtonsDB
    end
    BetterAddonButtonsDB = nil
    if type(CompactAddonButtonsDB) ~= "table" then CompactAddonButtonsDB = {} end
    ns.db = CompactAddonButtonsDB
    if type(ns.db.exceptions) ~= "table" then ns.db.exceptions = {} end
    if type(ns.db.angle) ~= "number" or ns.db.angle ~= ns.db.angle
        or math.abs(ns.db.angle) == math.huge then ns.db.angle = 220 end
    local p = ns.db.position
    local anchors = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    if type(p) ~= "table" or not anchors[p[1]] or not anchors[p[2]]
        or type(p[3]) ~= "number" or type(p[4]) ~= "number"
        or p[3] ~= p[3] or p[4] ~= p[4]
        or math.abs(p[3]) == math.huge or math.abs(p[4]) == math.huge then
        ns.db.position = { "CENTER", "CENTER", 0, 0 }
    end
    ns.db.version = 1
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        defaults()
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then defaults() end
        ns.CreateUI()
        ready = true
        ns.Scan()
    elseif ready and event == "PLAYER_REGEN_DISABLED" then
        ns.CloseForCombat()
        ns.launcher:SetScript("OnUpdate", nil)
    elseif ready and event == "PLAYER_REGEN_ENABLED" then
        ns.Scan()
        ns.PositionLauncher()
    elseif ready and event == "ADDON_LOADED" then
        -- Some addons create their buttons on the next frame; the periodic scan catches those too.
        elapsed = 2
    end
end)

events:SetScript("OnUpdate", function(_, delta)
    if not ready then return end
    elapsed = elapsed + delta
    if elapsed < 2 then return end
    elapsed = 0
    ns.Scan()
end)

SLASH_COMPACTADDONBUTTONS1 = "/cab"
SLASH_COMPACTADDONBUTTONS2 = "/compactaddonbuttons"
SLASH_COMPACTADDONBUTTONS3 = "/bab"
SLASH_COMPACTADDONBUTTONS4 = "/betteraddonbuttons"
SlashCmdList.COMPACTADDONBUTTONS = function(message)
    if not ready then return end
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "refresh" then ns.Scan()
    else ns.Toggle(command == "settings" or command == "options") end
end
