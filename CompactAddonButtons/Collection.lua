local addonName, ns = ...
ns.entries, ns.byButton = {}, {}
local unpack = unpack or table.unpack

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

local function forbidden(button)
    local name = button:GetName()
    return button == ns.launcher or (button.IsProtected and button:IsProtected())
        or (name and (native[name] or name:find("^Blizzard") or name:find("^CompactAddonButtons")
            or name:find("^BetterAddonButtons")))
end

local function snapshot(button)
    local saved = { parent = button:GetParent(), points = {},
        dragStart = button:GetScript("OnDragStart"), dragStop = button:GetScript("OnDragStop") }
    for i = 1, button:GetNumPoints() do saved.points[i] = { button:GetPoint(i) } end
    return saved
end

local function canChange(entry)
    return not InCombatLockdown() and not (entry.button.IsProtected and entry.button:IsProtected())
end

function ns.AnchorEntry(entry)
    if entry.changing or not entry.collected or not canChange(entry) then return end
    entry.changing = true
    local button = entry.button
    button:SetParent(entry.slot)
    button:ClearAllPoints()
    button:SetPoint("CENTER", entry.slot, "CENTER", 0, 0)
    entry.changing = false
end

function ns.ReleaseEntry(entry)
    if not entry.collected or not canChange(entry) then return end
    entry.changing, entry.collected = true, false
    local button, saved = entry.button, entry.original
    button:SetParent(saved.parent)
    button:ClearAllPoints()
    for _, point in ipairs(saved.points) do button:SetPoint(unpack(point)) end
    button:SetScript("OnDragStart", saved.dragStart)
    button:SetScript("OnDragStop", saved.dragStop)
    entry.slot:Hide()
    entry.changing = false
end

function ns.CollectEntry(entry)
    if entry.collected or not canChange(entry) then return end
    entry.original = snapshot(entry.button)
    entry.slot = entry.slot or ns.CreateSlot()
    entry.collected = true
    -- Disable only dragging while in the drawer; click/hover scripts are untouched.
    entry.button:SetScript("OnDragStart", nil)
    entry.button:SetScript("OnDragStop", nil)
    ns.AnchorEntry(entry)
end

function ns.RegisterButton(key, label, button)
    if not button or type(key) ~= "string" or key == "" or forbidden(button) then return false end
    if ns.byButton[button] then return false end
    local entry = { key = key, label = label or key, button = button }
    ns.entries[#ns.entries + 1], ns.byButton[button] = entry, entry
    for _, method in ipairs({ "SetPoint", "SetParent" }) do
        hooksecurefunc(button, method, function() ns.AnchorEntry(entry) end)
    end
    return true
end

function ns.Apply()
    if InCombatLockdown() then ns.pending = true; return end
    ns.pending = false
    for _, entry in ipairs(ns.entries) do
        if ns.db.exceptions[entry.key] then ns.ReleaseEntry(entry) else ns.CollectEntry(entry) end
    end
    ns.RefreshUI()
end

function ns.SetException(key, enabled)
    ns.db.exceptions[key] = enabled and true or nil
    ns.Apply()
end

local function libButtons()
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.GetButtonList or not lib.GetMinimapButton then return end
    for _, name in ipairs(lib:GetButtonList()) do
        local button = lib:GetMinimapButton(name)
        if button then
            local existing = ns.byButton[button]
            if existing and existing.key == "frame:" .. (button:GetName() or "") then
                local key = "lib:" .. name
                if ns.db.exceptions[existing.key] then ns.db.exceptions[key] = true end
                ns.db.exceptions[existing.key] = nil
                existing.key, existing.label = key, name
            else
                ns.RegisterButton("lib:" .. name, name, button)
            end
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

local function visit(parent, depth)
    if not parent or depth > 3 then return end
    for _, child in ipairs({ parent:GetChildren() }) do
        if not forbidden(child) then
            local name = child:GetName()
            if child:IsObjectType("Button") and name then
                local lower = name:lower()
                if hasIcon(child) and (parent == Minimap or parent == MinimapBackdrop
                    or lower:find("minimap", 1, true) or lower:find("libdbicon", 1, true)) then
                    local label = name:gsub("^LibDBIcon10_", ""):gsub("[Mm]ini[Mm]ap", "")
                        :gsub("[Bb]utton", ""):gsub("[_%-]+", " ")
                    if label:match("^%s*$") then label = name end
                    ns.RegisterButton("frame:" .. name, label, child)
                end
            end
            visit(child, depth + 1)
        end
    end
end

function ns.Scan()
    if InCombatLockdown() then ns.pending = true; return end
    libButtons()
    visit(Minimap, 0)
    if MinimapBackdrop and MinimapBackdrop ~= Minimap then visit(MinimapBackdrop, 0) end
    table.sort(ns.entries, function(a, b)
        if a.label:lower() == b.label:lower() then return a.key < b.key end
        return a.label:lower() < b.label:lower()
    end)
    ns.Apply()
end

-- Addons with unusual/anonymous buttons can opt in without a hard dependency.
CompactAddonButtons = {
    RegisterButton = function(key, label, button)
        if type(key) ~= "string" or key == "" then return false end
        local added = ns.RegisterButton("custom:" .. key, label, button)
        if added and ns.uiReady then ns.Apply() end
        return added
    end,
}
-- Preserve opt-in registrations written for the previous addon name.
BetterAddonButtons = CompactAddonButtons
