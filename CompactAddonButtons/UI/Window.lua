local _, ns = ...
local Window = {}
ns.Window = Window
local T = ns.Localization.Text
local text, skin, smallButton = ns.Widgets.Text, ns.Widgets.Skin, ns.Widgets.Button
local floor, max = math.floor, math.max
local rows, slots = {}, {}
local panel, content, scroll, empty, footer, search, modeButton
local header, close, scan, title, languageLabel, languageDropdown
local settingsMode = false
local query = ""
local WIDTH, HEIGHT, CELL, COLUMNS = 384, 394, 44, 5
local PADDING, MAX_ROWS = 8, 6

local function savePosition()
    local point, _, relativePoint, x, y = panel:GetPoint()
    ns.Settings.SetPosition(point, relativePoint, x, y)
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
        ns.App.SetException(self.entry.key, self:GetChecked())
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry.label)
        GameTooltip:AddLine(self.entry.key, 0.65, 0.65, 0.65, true)
        if not self.entry.button:IsShown() then GameTooltip:AddLine(T("HIDDEN"), 1, 0.8, 0.3) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

function Window.CreateSlot()
    local slot = CreateFrame("Frame", nil, content)
    slot:SetSize(CELL, CELL)
    slots[#slots + 1] = slot
    return slot
end

function Window.PositionPopup()
    local launcher = ns.MinimapButton.GetFrame()
    if not panel or not launcher or settingsMode then return end
    local x, y = launcher:GetCenter()
    if not x or not y then return end
    local scale = launcher:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right = x * scale > UIParent:GetWidth() / 2
    local top = y * scale > UIParent:GetHeight() / 2
    local point = (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
    local relative = (top and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
    panel:ClearAllPoints()
    panel:SetPoint(point, launcher, relative, right and -6 or 6, 0)
end

local function layout(count)
    header:SetShown(settingsMode)
    close:SetShown(settingsMode)
    search:SetShown(settingsMode)
    modeButton:SetShown(settingsMode)
    scan:SetShown(settingsMode)
    footer:SetShown(settingsMode)
    languageLabel:SetShown(settingsMode)
    languageDropdown:SetShown(settingsMode)
    scroll:ClearAllPoints()
    empty:ClearAllPoints()
    if settingsMode then
        panel:SetSize(WIDTH, HEIGHT)
        scroll:SetPoint("TOPLEFT", 16, -120)
        scroll:SetPoint("BOTTOMRIGHT", -30, 52)
        content:SetWidth(336)
        empty:SetPoint("TOPLEFT", 24, -170)
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
        Window.PositionPopup()
    end
    local bar = scroll.ScrollBar or _G["CompactAddonButtonsScrollScrollBar"]
    if bar then bar:SetShown(settingsMode or count > COLUMNS * MAX_ROWS) end
end

function Window.Refresh()
    if not panel or InCombatLockdown() then return end
    Window.RefreshTexts()
    local visible = {}
    for _, entry in ipairs(ns.Buttons.All()) do
        if settingsMode then
            if ns.Buttons.Matches(entry, query) then visible[#visible + 1] = entry end
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
            row:SetChecked(ns.Settings.IsException(entry.key))
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
    modeButton:SetText(settingsMode and T("BACK") or T("SETTINGS"))
    footer:SetText(ns.App.IsPending() and T("COMBAT") or (settingsMode and T("EXCEPTIONS") or T("HINT")))
    local range = max(0, content:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), range))
end

local function setMode(value)
    settingsMode = value
    if settingsMode then
        local point, relative, x, y = ns.Settings.GetPosition()
        panel:ClearAllPoints()
        panel:SetPoint(point, UIParent, relative, x, y)
    end
    scroll:SetVerticalScroll(0)
    Window.Refresh()
end

function Window.Toggle(settings)
    if panel:IsShown() and settings == settingsMode then panel:Hide(); return end
    setMode(settings == true)
    panel:Show()
end

function Window.Close()
    -- Hide the drawer before allowing any protected state changes from other addons.
    if panel then panel:Hide() end
end

function Window.Create()
    panel = CreateFrame("Frame", "CompactAddonButtonsWindow", UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    skin(panel)
    local point, relative, x, y = ns.Settings.GetPosition()
    panel:SetPoint(point, UIParent, relative, x, y)
    tinsert(UISpecialFrames, "CompactAddonButtonsWindow")

    header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(42)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() panel:StartMoving() end)
    header:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); savePosition() end)
    title = text(header, "GameFontNormalLarge", T("TITLE"), 16, -14)
    close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() panel:Hide() end)

    languageLabel = text(panel, "GameFontNormal", T("LANGUAGE"), 16, -49)
    languageLabel:SetWidth(88)
    languageDropdown = CreateFrame("DropdownButton", "CompactAddonButtonsLanguage", panel, "WowStyle1DropdownTemplate")
    languageDropdown:SetPoint("TOPLEFT", 108, -40)
    languageDropdown:SetWidth(260)
    languageDropdown:SetupMenu(function(_, root)
        local function selected(value) return ns.Settings.GetLanguage() == value end
        local function choose(value) ns.App.SetLanguage(value) end
        root:CreateRadio(T("AUTO_LANGUAGE"), selected, choose, "auto")
        for _, language in ipairs(ns.Localization.GetLanguages()) do
            root:CreateRadio(language.name, selected, choose, language.locale)
        end
        local preference = ns.Settings.GetLanguage()
        if preference ~= "auto" and not ns.Localization.IsSupported(preference) then
            root:CreateRadio(preference, selected, choose, preference):SetEnabled(false)
        end
    end)

    modeButton = smallButton(panel, T("SETTINGS"), 108)
    modeButton:SetPoint("TOPRIGHT", -16, -82)
    modeButton:SetScript("OnClick", function() setMode(not settingsMode) end)
    scan = smallButton(panel, T("SCAN"), 84)
    scan:SetPoint("BOTTOMRIGHT", -14, 12)
    scan:SetScript("OnClick", function() ns.App.Scan() end)

    search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(190, 22)
    search:SetPoint("TOPLEFT", 20, -82)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        query = self:GetText():lower()
        if self.hint then self.hint:SetShown(query == "") end
        scroll:SetVerticalScroll(0)
        Window.Refresh()
    end)
    search.hint = text(search, "GameFontDisableSmall", T("SEARCH"), 0, -5)
    panel:SetScript("OnHide", function() search:ClearFocus(); GameTooltip:Hide() end)

    scroll = CreateFrame("ScrollFrame", "CompactAddonButtonsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -120)
    scroll:SetPoint("BOTTOMRIGHT", -30, 52)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(COLUMNS * CELL, 1)
    scroll:SetScrollChild(content)
    empty = text(panel, "GameFontDisable", T("EMPTY"), 24, -130)
    empty:SetWidth(330)
    empty:SetJustifyH("CENTER")
    footer = text(panel, "GameFontDisableSmall", T("HINT"), 16, -(HEIGHT - 48))
    footer:SetWidth(340)
    footer:SetJustifyH("LEFT")

end

function Window.GetFrame() return panel end
function Window.RefreshTexts()
    if not panel then return end
    title:SetText(T("TITLE"))
    empty:SetText(T("EMPTY"))
    search.hint:SetText(T("SEARCH"))
    scan:SetText(T("SCAN"))
    languageLabel:SetText(T("LANGUAGE"))
    languageDropdown:GenerateMenu()
end
