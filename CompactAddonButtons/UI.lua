local _, ns = ...
local L = ns.L
local floor, max = math.floor, math.max
local rows, slots = {}, {}
local panel, content, scroll, empty, footer, search, modeButton
local header, close, scan
local settingsMode = false
local query = ""
local WIDTH, HEIGHT, CELL, COLUMNS = 384, 350, 44, 5
local PADDING, MAX_ROWS = 8, 6

local function text(parent, font, value, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(value)
    return label
end

local function skin(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    frame:SetBackdropColor(0.055, 0.05, 0.045, 0.97)
    frame:SetBackdropBorderColor(0.40, 0.33, 0.21, 0.95)
end

local function smallButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    return button
end

local function savePosition()
    local point, _, relativePoint, x, y = panel:GetPoint()
    ns.db.position = { point, relativePoint, x, y }
end

local function rowAt(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    row:SetSize(26, 26)
    row.label = text(row, "GameFontHighlight", "", 30, -5)
    row.label:SetWidth(270)
    row.label:SetJustifyH("LEFT")
    row:SetHitRectInsets(0, -280, 0, 0)
    row:SetScript("OnClick", function(self)
        ns.SetException(self.entry.key, self:GetChecked())
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry.label)
        GameTooltip:AddLine(self.entry.key, 0.65, 0.65, 0.65, true)
        if not self.entry.button:IsShown() then GameTooltip:AddLine(L.HIDDEN, 1, 0.8, 0.3) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

function ns.CreateSlot()
    local slot = CreateFrame("Frame", nil, content)
    slot:SetSize(CELL, CELL)
    slots[#slots + 1] = slot
    return slot
end

function ns.PositionPopup()
    if not panel or not ns.launcher or settingsMode then return end
    local x, y = ns.launcher:GetCenter()
    if not x or not y then return end
    local scale = ns.launcher:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right = x * scale > UIParent:GetWidth() / 2
    local top = y * scale > UIParent:GetHeight() / 2
    local point = (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
    local relative = (top and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
    panel:ClearAllPoints()
    panel:SetPoint(point, ns.launcher, relative, right and -6 or 6, 0)
end

local function layout(count)
    header:SetShown(settingsMode)
    close:SetShown(settingsMode)
    search:SetShown(settingsMode)
    modeButton:SetShown(settingsMode)
    scan:SetShown(settingsMode)
    footer:SetShown(settingsMode)
    scroll:ClearAllPoints()
    empty:ClearAllPoints()
    if settingsMode then
        panel:SetSize(WIDTH, HEIGHT)
        scroll:SetPoint("TOPLEFT", 16, -78)
        scroll:SetPoint("BOTTOMRIGHT", -30, 52)
        content:SetWidth(336)
        empty:SetPoint("TOPLEFT", 24, -130)
        empty:SetWidth(330)
    else
        local columns = math.min(COLUMNS, max(1, count))
        local rowsNeeded = max(1, math.ceil(count / columns))
        local overflow = rowsNeeded > MAX_ROWS
        local width = count == 0 and 210 or columns * CELL + PADDING * 2
        panel:SetSize(width + (overflow and 20 or 0), math.min(MAX_ROWS, rowsNeeded) * CELL + PADDING * 2)
        scroll:SetPoint("TOPLEFT", PADDING, -PADDING)
        scroll:SetPoint("BOTTOMRIGHT", -(PADDING + (overflow and 20 or 0)), PADDING)
        content:SetWidth(columns * CELL)
        empty:SetPoint("CENTER", panel, "CENTER", 0, 0)
        empty:SetWidth(width - PADDING * 2)
        ns.PositionPopup()
    end
    local bar = scroll.ScrollBar or _G["CompactAddonButtonsScrollScrollBar"]
    if bar then bar:SetShown(settingsMode or count > COLUMNS * MAX_ROWS) end
end

function ns.RefreshUI()
    if not panel or InCombatLockdown() then return end
    local visible = {}
    for _, entry in ipairs(ns.entries) do
        if settingsMode then
            if query == "" or entry.label:lower():find(query, 1, true)
                or entry.key:lower():find(query, 1, true) then visible[#visible + 1] = entry end
        elseif entry.collected and entry.button:IsShown() then
            visible[#visible + 1] = entry
        end
    end
    local columns = math.min(COLUMNS, max(1, #visible))
    layout(#visible)
    local count, activeSlots = 0, {}
    for _, entry in ipairs(visible) do
        if settingsMode then
            count = count + 1
            local row = rowAt(count)
            row.entry = entry
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(count - 1) * 30)
            row.label:SetText(entry.label)
            row.label:SetTextColor(1, entry.button:IsShown() and 0.95 or 0.6, entry.button:IsShown() and 0.85 or 0.6)
            row:SetChecked(ns.db.exceptions[entry.key] == true)
            row:Show()
        else
            local slot = entry.slot
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", (count % columns) * CELL, -floor(count / columns) * CELL)
            activeSlots[slot] = true
            count = count + 1
        end
    end
    -- Do not hide and re-show every button on each scan: addon OnShow/OnHide scripts
    -- may have side effects, even though the visible layout has not changed.
    for _, slot in ipairs(slots) do slot:SetShown(activeSlots[slot] == true) end
    for i, row in ipairs(rows) do row:SetShown(settingsMode and i <= count) end
    content:SetHeight(max(1, settingsMode and count * 30 or math.ceil(count / columns) * CELL))
    empty:SetShown(count == 0)
    modeButton:SetText(settingsMode and L.BACK or L.SETTINGS)
    footer:SetText(ns.pending and L.COMBAT or (settingsMode and L.EXCEPTIONS or L.HINT))
    local range = max(0, content:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), range))
end

local function setMode(value)
    settingsMode = value
    if settingsMode then
        local p = ns.db.position
        panel:ClearAllPoints()
        panel:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    scroll:SetVerticalScroll(0)
    ns.RefreshUI()
end

function ns.Toggle(settings)
    if InCombatLockdown() then
        print("|cffffd100CompactAddonButtons:|r " .. L.LOCKED)
        return
    end
    if panel:IsShown() and settings == settingsMode then panel:Hide(); return end
    ns.Scan()
    setMode(settings == true)
    panel:Show()
end

function ns.CloseForCombat()
    -- Hide the drawer before allowing any protected state changes from other addons.
    if panel then panel:Hide() end
end

function ns.PositionLauncher()
    local angle = math.rad(ns.db.angle)
    local radiusX, radiusY = Minimap:GetWidth() / 2 + 7, Minimap:GetHeight() / 2 + 7
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local rounded = {
        ROUND = { true, true, true, true }, SQUARE = {},
        ["CORNER-TOPLEFT"] = { false, false, false, true },
        ["CORNER-TOPRIGHT"] = { false, false, true, false },
        ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
        ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
        ["SIDE-LEFT"] = { false, true, false, true },
        ["SIDE-RIGHT"] = { true, false, true, false },
        ["SIDE-TOP"] = { false, false, true, true },
        ["SIDE-BOTTOM"] = { true, true, false, false },
        ["TRICORNER-TOPLEFT"] = { false, true, true, true },
        ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
        ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
        ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
    }
    local quadrant = (x < 0 and 1 or 0) + (y > 0 and 2 or 0) + 1
    if rounded[shape] and not rounded[shape][quadrant] then
        local divisor = max(math.abs(x), math.abs(y))
        x, y = x / divisor, y / divisor
    end
    ns.launcher:ClearAllPoints()
    ns.launcher:SetPoint("CENTER", Minimap, "CENTER", x * radiusX, y * radiusY)
end

function ns.CreateUI()
    panel = CreateFrame("Frame", "CompactAddonButtonsWindow", UIParent, "BackdropTemplate")
    ns.panel = panel
    panel:Hide()
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    skin(panel)
    local position = ns.db.position
    panel:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    tinsert(UISpecialFrames, "CompactAddonButtonsWindow")

    header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(42)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() panel:StartMoving() end)
    header:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); savePosition() end)
    text(header, "GameFontNormalLarge", L.TITLE, 16, -14)
    close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() panel:Hide() end)

    modeButton = smallButton(panel, L.SETTINGS, 108)
    modeButton:SetPoint("TOPRIGHT", -36, -42)
    modeButton:SetScript("OnClick", function() setMode(not settingsMode) end)
    scan = smallButton(panel, L.SCAN, 84)
    scan:SetPoint("BOTTOMRIGHT", -14, 12)
    scan:SetScript("OnClick", function() ns.Scan() end)

    search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(190, 22)
    search:SetPoint("TOPLEFT", 20, -42)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        query = self:GetText():lower()
        if self.hint then self.hint:SetShown(query == "") end
        scroll:SetVerticalScroll(0)
        ns.RefreshUI()
    end)
    search.hint = text(search, "GameFontDisableSmall", L.SEARCH, 0, -5)
    panel:SetScript("OnHide", function() search:ClearFocus(); GameTooltip:Hide() end)

    scroll = CreateFrame("ScrollFrame", "CompactAddonButtonsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -78)
    scroll:SetPoint("BOTTOMRIGHT", -30, 52)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(COLUMNS * CELL, 1)
    scroll:SetScrollChild(content)
    empty = text(panel, "GameFontDisable", L.EMPTY, 24, -130)
    empty:SetWidth(330)
    empty:SetJustifyH("CENTER")
    footer = text(panel, "GameFontDisableSmall", L.HINT, 16, -(HEIGHT - 48))
    footer:SetWidth(340)
    footer:SetJustifyH("LEFT")

    local button = CreateFrame("Button", "CompactAddonButtonsMinimapButton", Minimap)
    ns.launcher = button
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Black")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(_, mouse) ns.Toggle(mouse == "RightButton") end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Compact Addon Buttons", 1, 0.82, 0)
        GameTooltip:AddLine(L.LEFT_CLICK, 1, 1, 1)
        GameTooltip:AddLine(L.RIGHT_CLICK, 1, 1, 1)
        GameTooltip:AddLine(L.DRAG, 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            ns.db.angle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
            ns.PositionLauncher()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    Minimap:HookScript("OnSizeChanged", function()
        if not InCombatLockdown() then ns.PositionLauncher() end
    end)
    ns.PositionLauncher()
    ns.uiReady = true
end
