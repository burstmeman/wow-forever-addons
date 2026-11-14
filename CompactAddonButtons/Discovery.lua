local _, ns = ...
local Discovery = {}
ns.Discovery = Discovery

-- These are game controls, never addon launchers. Skip their subtrees too.
local native = {
    Minimap = true, MinimapCluster = true, MinimapBackdrop = true,
    MinimapZoomIn = true, MinimapZoomOut = true, MiniMapTracking = true,
    MiniMapTrackingButton = true, MiniMapWorldMapButton = true,
    MiniMapMailFrame = true, MiniMapMailIcon = true, MiniMapBattlefieldFrame = true,
    MiniMapLFGFrame = true, MiniMapLFGFrameDropDown = true, MiniMapInstanceDifficulty = true,
    GuildInstanceDifficulty = true, MiniMapChallengeMode = true, MinimapZoneTextButton = true,
    GameTimeFrame = true, TimeManagerClockButton = true, QueueStatusMinimapButton = true,
    QueueStatusButton = true, GarrisonLandingPageMinimapButton = true,
    ExpansionLandingPageMinimapButton = true, MiniMapVoiceChatFrame = true,
    MiniMapVoiceChatFrameButton = true, MinimapNorthTag = true,
    MinimapCompassTexture = true, MiniMapPing = true, MinimapBorder = true,
    MinimapBorderTop = true, MinimapToggleButton = true, MinimapToggle = true,
    MiniMapRecordingButton = true, FeedbackUIButton = true,
}

function Discovery.IsExcluded(button)
    local name = button:GetName()
    return (button.IsProtected and button:IsProtected())
        or (name and (native[name] or name:find("^Blizzard") or name:find("^CompactAddonButtons")
            or name:find("^BetterAddonButtons")))
end

local function libButtons(register)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.GetButtonList or not lib.GetMinimapButton then return end
    for _, name in ipairs(lib:GetButtonList()) do
        local button = lib:GetMinimapButton(name)
        if button then
            register("lib:" .. name, name, button)
        end
    end
end

local function hasIcon(button)
    if button.icon or button.Icon or button:GetNormalTexture() then return true end
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") then return true end
    end
    return false
end

local function visit(parent, depth, register)
    if not parent or depth > 3 then return end
    for _, child in ipairs({ parent:GetChildren() }) do
        if not Discovery.IsExcluded(child) then
            local name = child:GetName()
            if child:IsObjectType("Button") and name then
                local lower = name:lower()
                if hasIcon(child) and (parent == Minimap or parent == MinimapBackdrop
                    or lower:find("minimap", 1, true) or lower:find("libdbicon", 1, true)) then
                    local label = name:gsub("^LibDBIcon10_", ""):gsub("[Mm]ini[Mm]ap", "")
                        :gsub("[Bb]utton", ""):gsub("[_%-]+", " ")
                    if label:match("^%s*$") then label = name end
                    register("frame:" .. name, label, child)
                end
            end
            visit(child, depth + 1, register)
        end
    end
end

function Discovery.Scan(register)
    libButtons(register)
    visit(Minimap, 0, register)
    if MinimapBackdrop and MinimapBackdrop ~= Minimap then visit(MinimapBackdrop, 0, register) end
end
