local addonName, ns = ...
local events = CreateFrame("Frame")
local elapsed, SCAN_INTERVAL = 0, 2
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then
            ns.App.Initialize()
        elseif ns.App.IsReady() then
            elapsed = SCAN_INTERVAL
        end
    elseif event == "PLAYER_LOGIN" then
        ns.App.Start()
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.App.OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.App.OnCombatEnd()
    end
end)

events:SetScript("OnUpdate", function(_, delta)
    if not ns.App.IsReady() then return end
    elapsed = elapsed + delta
    if elapsed < SCAN_INTERVAL then return end
    elapsed = 0
    ns.App.Scan()
end)

SLASH_COMPACTADDONBUTTONS1 = "/cab"
SLASH_COMPACTADDONBUTTONS2 = "/compactaddonbuttons"
SLASH_COMPACTADDONBUTTONS3 = "/bab"
SLASH_COMPACTADDONBUTTONS4 = "/betteraddonbuttons"
SlashCmdList.COMPACTADDONBUTTONS = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "refresh" then
        ns.App.Scan()
    else
        ns.App.Toggle(command == "settings" or command == "options")
    end
end
