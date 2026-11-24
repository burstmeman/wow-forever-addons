local _, ns = ...
local Discovery = {}
ns.Discovery = Discovery

-- These are game controls, never addon launchers. Skip their subtrees too.
local native = {
    Minimap = true,
    MinimapCluster = true,
    MinimapBackdrop = true,
    MinimapZoomIn = true,
    MinimapZoomOut = true,
    MiniMapTracking = true,
    MiniMapTrackingButton = true,
    MiniMapWorldMapButton = true,
    MiniMapMailFrame = true,
    MiniMapMailIcon = true,
    MiniMapBattlefieldFrame = true,
    MiniMapLFGFrame = true,
    MiniMapLFGFrameDropDown = true,
    MiniMapInstanceDifficulty = true,
    GuildInstanceDifficulty = true,
    MiniMapChallengeMode = true,
    MinimapZoneTextButton = true,
    GameTimeFrame = true,
    TimeManagerClockButton = true,
    QueueStatusMinimapButton = true,
    QueueStatusButton = true,
    GarrisonLandingPageMinimapButton = true,
    ExpansionLandingPageMinimapButton = true,
    MiniMapVoiceChatFrame = true,
    MiniMapVoiceChatFrameButton = true,
    MinimapNorthTag = true,
    MinimapCompassTexture = true,
    MiniMapPing = true,
    MinimapBorder = true,
    MinimapBorderTop = true,
    MinimapToggleButton = true,
    MinimapToggle = true,
    MiniMapRecordingButton = true,
    FeedbackUIButton = true,
}

function Discovery.IsExcluded(button)
    local name = button:GetName()
    return (button.IsProtected and button:IsProtected())
        or (
            name
            and (
                native[name]
                or name:find("^Blizzard")
                or name:find("^CompactAddonButtons")
                or name:find("^BetterAddonButtons")
            )
        )
end

local function libButtons(register)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.GetButtonList or not lib.GetMinimapButton then return end
    for _, name in ipairs(lib:GetButtonList()) do
        local button = lib:GetMinimapButton(name)
        if button then register("lib:" .. name, name, button) end
    end
end

local childBuffers, regionBuffer = {}, {}

local function acquire()
    local buffer = childBuffers[#childBuffers]
    if buffer then
        childBuffers[#childBuffers] = nil
    else
        buffer = {}
    end
    return buffer
end

local function release(buffer)
    for index = 1, #buffer do
        buffer[index] = nil
    end
    childBuffers[#childBuffers + 1] = buffer
end

local function packInto(buffer, ...)
    local count = select("#", ...)
    for index = 1, count do
        buffer[index] = select(index, ...)
    end
    for index = count + 1, #buffer do
        buffer[index] = nil
    end
    return count
end

local function hasIcon(button)
    if button.icon or button.Icon or button:GetNormalTexture() then return true end
    local count = packInto(regionBuffer, button:GetRegions())
    for index = 1, count do
        local region = regionBuffer[index]
        if region and region:IsObjectType("Texture") then return true end
    end
    return false
end

function Discovery.Label(name)
    local label = name:gsub("^LibDBIcon10_", ""):gsub("[Mm]ini[Mm]ap", ""):gsub("[Bb]utton", ""):gsub("[_%-]+", " ")
    if label:match("^%s*$") then return name end
    return label
end

local function visit(parent, depth, register)
    if not parent or depth > 3 then return end
    local buffer = acquire()
    local count = packInto(buffer, parent:GetChildren())
    for index = 1, count do
        local child = buffer[index]
        if child and not Discovery.IsExcluded(child) then
            local name = child:GetName()
            -- Buttons already in the catalog keep their label. Their children can still be new.
            if child:IsObjectType("Button") and name and not ns.Buttons.Find(child) then
                local lower = name:lower()
                if
                    hasIcon(child)
                    and (
                        parent == Minimap
                        or parent == MinimapBackdrop
                        or lower:find("minimap", 1, true)
                        or lower:find("libdbicon", 1, true)
                    )
                then
                    register("frame:" .. name, Discovery.Label(name), child)
                end
            end
            visit(child, depth + 1, register)
        end
    end
    release(buffer)
end

function Discovery.Scan(register)
    libButtons(register)
    visit(Minimap, 0, register)
    if MinimapBackdrop and MinimapBackdrop ~= Minimap then visit(MinimapBackdrop, 0, register) end
end
