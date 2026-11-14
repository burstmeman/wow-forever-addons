local _, ns = ...
local Collection = {}
ns.Collection = Collection
local unpack = unpack or table.unpack

local function snapshot(button)
    local saved = { parent = button:GetParent(), points = {},
        dragStart = button:GetScript("OnDragStart"), dragStop = button:GetScript("OnDragStop") }
    for i = 1, button:GetNumPoints() do saved.points[i] = { button:GetPoint(i) } end
    return saved
end

local function canChange(entry)
    return not InCombatLockdown() and not (entry.button.IsProtected and entry.button:IsProtected())
end

function Collection.Anchor(entry)
    if entry.changing or not entry.collected or not canChange(entry) then return end
    entry.changing = true
    local button = entry.button
    button:SetParent(entry.slot)
    button:ClearAllPoints()
    button:SetPoint("CENTER", entry.slot, "CENTER", 0, 0)
    entry.changing = false
end

function Collection.Release(entry)
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

function Collection.Collect(entry, createSlot)
    if entry.collected or not canChange(entry) then return end
    entry.original = snapshot(entry.button)
    entry.slot = entry.slot or createSlot()
    entry.collected = true
    -- Disable only dragging while in the drawer; click/hover scripts are untouched.
    entry.button:SetScript("OnDragStart", nil)
    entry.button:SetScript("OnDragStop", nil)
    Collection.Anchor(entry)
end

function Collection.Watch(entry)
    for _, method in ipairs({ "SetPoint", "SetParent" }) do
        hooksecurefunc(entry.button, method, function() Collection.Anchor(entry) end)
    end
end
