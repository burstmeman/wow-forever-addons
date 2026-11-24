local _, ns = ...
local Window = {}
ns.Window = Window
local T = ns.Localization.Text
local text, skin, smallButton = ns.Widgets.Text, ns.Widgets.Skin, ns.Widgets.Button
local floor, max = math.floor, math.max
local rows, slots = {}, {}
local panel, content, gridContent, scroll, empty, footer, search, modeButton
local header, close, scan, title, languageLabel, languageDropdown
local columnsLabel, columnsDropdown
local manualCheck, manualLabel, anchorLabel, anchorDropdown, offsetLabel, offsetBox
local settingsMode = false
local query = ""
local textLocale, textRevision, menuPreference, menuColumns, menuPopupAnchor
local lastLayout, popupManual, popupAnchor, popupOffset, popupX, popupY, popupScale
local WIDTH, HEIGHT, CELL = 384, 432, 32
local PADDING = 3

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
    row:SetScript("OnClick", function(self) ns.App.SetException(self.entry.key, self:GetChecked()) end)
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
    local slot = CreateFrame("Frame", nil, gridContent)
    slot:SetFrameStrata(gridContent:GetFrameStrata())
    slot:SetFrameLevel(gridContent:GetFrameLevel() + 1)
    slot:SetSize(CELL, CELL)
    slots[#slots + 1] = slot
    return slot
end

function Window.GridMetrics(count, columnLimit)
    local columns = math.min(columnLimit, max(1, count))
    if columns < 1 then columns = 1 end
    local rows = max(1, math.ceil(count / columns))
    local width = count == 0 and 210 or columns * CELL + PADDING * 2
    return columns, rows, width, rows * CELL + PADDING * 2
end

-- The named side is where the window sits relative to the launcher.
-- The returned point is the window edge that touches that side.
local POPUP_POINTS = {
    LEFT = { "RIGHT", "LEFT", -1, 0 },
    RIGHT = { "LEFT", "RIGHT", 1, 0 },
    TOP = { "BOTTOM", "TOP", 0, 1 },
    BOTTOM = { "TOP", "BOTTOM", 0, -1 },
    TOPLEFT = { "BOTTOMRIGHT", "TOPLEFT", -1, 1 },
    TOPRIGHT = { "BOTTOMLEFT", "TOPRIGHT", 1, 1 },
    BOTTOMLEFT = { "TOPRIGHT", "BOTTOMLEFT", -1, -1 },
    BOTTOMRIGHT = { "TOPLEFT", "BOTTOMRIGHT", 1, -1 },
}

function Window.PopupPoint(anchor, offset)
    local spec = POPUP_POINTS[anchor]
    return spec[1], spec[2], spec[3] * offset, spec[4] * offset
end

function Window.PositionPopup()
    local launcher = ns.MinimapButton.GetFrame()
    if not panel or not launcher or settingsMode then return false end
    local point, relative, x, y
    if ns.Settings.GetPopupManual() then
        point, relative, x, y = Window.PopupPoint(ns.Settings.GetPopupAnchor(), ns.Settings.GetPopupOffset())
    else
        local centerX, centerY = launcher:GetCenter()
        if not centerX or not centerY then return false end
        local scale = launcher:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local right = centerX * scale > UIParent:GetWidth() / 2
        local top = centerY * scale > UIParent:GetHeight() / 2
        point = (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
        relative = (top and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
        x, y = right and -6 or 6, 0
    end
    panel:ClearAllPoints()
    panel:SetPoint(point, launcher, relative, x, y)
    return true
end

local function layout(count)
    panel:SetBackdropColor(0.055, 0.05, 0.045, settingsMode and 0.97 or 0.88)
    header:SetShown(settingsMode)
    close:SetShown(settingsMode)
    search:SetShown(settingsMode)
    modeButton:SetShown(settingsMode)
    scan:SetShown(settingsMode)
    footer:SetShown(settingsMode)
    languageLabel:SetShown(settingsMode)
    languageDropdown:SetShown(settingsMode)
    columnsLabel:SetShown(settingsMode)
    columnsDropdown:SetShown(settingsMode)
    manualCheck:SetShown(settingsMode)
    manualLabel:SetShown(settingsMode)
    anchorLabel:SetShown(settingsMode)
    anchorDropdown:SetShown(settingsMode)
    offsetLabel:SetShown(settingsMode)
    offsetBox:SetShown(settingsMode)
    scroll:SetShown(settingsMode)
    gridContent:SetShown(not settingsMode)
    scroll:ClearAllPoints()
    empty:ClearAllPoints()
    if settingsMode then
        panel:SetSize(WIDTH, HEIGHT)
        scroll:SetPoint("TOPLEFT", 16, -228)
        scroll:SetPoint("BOTTOMRIGHT", -30, 52)
        content:SetWidth(336)
        empty:SetPoint("TOPLEFT", 24, -278)
        empty:SetWidth(330)
    else
        local columns, rows, width, height = Window.GridMetrics(count, ns.Settings.GetColumns())
        panel:SetSize(width, height)
        gridContent:SetSize(columns * CELL, rows * CELL)
        empty:SetPoint("CENTER", panel, "CENTER", 0, 0)
        empty:SetWidth(width - PADDING * 2)
    end
    local bar = scroll.ScrollBar or _G["CompactAddonButtonsScrollScrollBar"]
    if bar then bar:SetShown(settingsMode) end
end

local function writeText(widget, value)
    if widget:GetText() ~= value then widget:SetText(value) end
end

local function updateChrome()
    writeText(modeButton, settingsMode and T("BACK") or T("SETTINGS"))
    writeText(footer, ns.App.IsPending() and T("COMBAT") or (settingsMode and T("EXCEPTIONS") or T("HINT")))
end

local function layoutKey(visible, columns)
    local parts = { settingsMode and "settings" or "grid", tostring(columns), query }
    for index = 1, #visible do
        local entry = visible[index]
        parts[#parts + 1] = entry.key
        parts[#parts + 1] = entry.label
        parts[#parts + 1] = entry.button:IsShown() and "1" or "0"
        parts[#parts + 1] = ns.Settings.IsException(entry.key) and "1" or "0"
    end
    return table.concat(parts, "\n")
end

local function placePopup(force)
    if settingsMode then return end
    local launcher = ns.MinimapButton.GetFrame()
    local manual = ns.Settings.GetPopupManual()
    local anchor, offset = ns.Settings.GetPopupAnchor(), ns.Settings.GetPopupOffset()
    local x, y, scale
    if launcher then
        x, y = launcher:GetCenter()
        scale = launcher:GetEffectiveScale()
    end
    if
        not force
        and manual == popupManual
        and anchor == popupAnchor
        and offset == popupOffset
        and x == popupX
        and y == popupY
        and scale == popupScale
    then
        return
    end
    if not Window.PositionPopup() then return end
    popupManual, popupAnchor, popupOffset, popupX, popupY, popupScale = manual, anchor, offset, x, y, scale
end

function Window.IsShown() return panel ~= nil and panel:IsShown() end

function Window.Refresh(force)
    if not panel or InCombatLockdown() then return end
    Window.RefreshTexts()
    -- Keep labels current, but defer hidden layout work until the next opening.
    if not force and not panel:IsShown() then return end
    local visible = {}
    for _, entry in ipairs(ns.Buttons.All()) do
        if settingsMode then
            if ns.Buttons.Matches(entry, query) then visible[#visible + 1] = entry end
        elseif entry.collected and entry.button:IsShown() then
            visible[#visible + 1] = entry
        end
    end
    local columns = Window.GridMetrics(#visible, ns.Settings.GetColumns())
    local key = layoutKey(visible, columns)
    if not force and key == lastLayout then
        updateChrome()
        placePopup(false)
        return
    end
    lastLayout = key
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
    for _, slot in ipairs(slots) do
        slot:SetShown(activeSlots[slot] == true)
    end
    for i, row in ipairs(rows) do
        row:SetShown(settingsMode and i <= count)
    end
    if settingsMode then content:SetHeight(max(1, count * 30)) end
    empty:SetShown(count == 0)
    updateChrome()
    placePopup(true)
    local range = settingsMode and max(0, content:GetHeight() - scroll:GetHeight()) or 0
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
    Window.Refresh(true)
end

function Window.Toggle(settings)
    if panel:IsShown() and settings == settingsMode then
        panel:Hide()
        return
    end
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
    header:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        savePosition()
    end)
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

    columnsLabel = text(panel, "GameFontNormal", T("BUTTONS_PER_ROW"), 16, -87)
    columnsLabel:SetWidth(160)
    columnsDropdown = CreateFrame("DropdownButton", "CompactAddonButtonsColumns", panel, "WowStyle1DropdownTemplate")
    columnsDropdown:SetPoint("TOPLEFT", 180, -78)
    columnsDropdown:SetWidth(188)
    columnsDropdown:SetupMenu(function(_, root)
        local function selected(value) return ns.Settings.GetColumns() == value end
        local function choose(value) ns.App.SetColumns(value) end
        for value = ns.Settings.MIN_COLUMNS, ns.Settings.MAX_COLUMNS do
            root:CreateRadio(tostring(value), selected, choose, value)
        end
    end)

    manualCheck = CreateFrame("CheckButton", "CompactAddonButtonsPopupManual", panel, "UICheckButtonTemplate")
    manualCheck:SetSize(26, 26)
    manualCheck:SetPoint("TOPLEFT", 12, -114)
    manualCheck:SetChecked(ns.Settings.GetPopupManual())
    manualCheck:SetScript("OnClick", function(self) ns.App.SetPopupManual(self:GetChecked()) end)
    manualLabel = text(panel, "GameFontNormal", T("POPUP_MANUAL"), 40, -120)
    manualLabel:SetWidth(320)
    anchorLabel = text(panel, "GameFontNormal", T("POPUP_ANCHOR"), 16, -152)
    anchorLabel:SetWidth(88)
    anchorDropdown = CreateFrame("DropdownButton", "CompactAddonButtonsPopupAnchor", panel, "WowStyle1DropdownTemplate")
    anchorDropdown:SetPoint("TOPLEFT", 108, -143)
    anchorDropdown:SetWidth(120)
    anchorDropdown:SetupMenu(function(_, root)
        local function selected(value) return ns.Settings.GetPopupAnchor() == value end
        local function choose(value) ns.App.SetPopup(value, nil) end
        for _, anchor in ipairs(ns.Settings.POPUP_ANCHORS) do
            root:CreateRadio(T("ANCHOR_" .. anchor), selected, choose, anchor)
        end
    end)
    offsetLabel = text(panel, "GameFontNormal", T("POPUP_OFFSET"), 236, -152)
    offsetLabel:SetWidth(70)
    offsetBox = CreateFrame("EditBox", "CompactAddonButtonsPopupOffset", panel, "InputBoxTemplate")
    offsetBox:SetSize(52, 22)
    offsetBox:SetPoint("TOPLEFT", 310, -148)
    offsetBox:SetAutoFocus(false)
    offsetBox:SetMaxLetters(3)
    offsetBox:SetText(tostring(ns.Settings.GetPopupOffset()))
    local committing = false
    local function commitOffset(self)
        if committing then return end
        committing = true
        local value = tonumber(self:GetText())
        if not ns.App.SetPopup(nil, value) then self:SetText(tostring(ns.Settings.GetPopupOffset())) end
        self:ClearFocus()
        committing = false
    end
    offsetBox:SetScript("OnEnterPressed", commitOffset)
    offsetBox:SetScript("OnEditFocusLost", commitOffset)
    offsetBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(ns.Settings.GetPopupOffset()))
        self:ClearFocus()
    end)

    modeButton = smallButton(panel, T("SETTINGS"), 108)
    modeButton:SetPoint("TOPRIGHT", -16, -190)
    modeButton:SetScript("OnClick", function() setMode(not settingsMode) end)
    scan = smallButton(panel, T("SCAN"), 84)
    scan:SetPoint("BOTTOMRIGHT", -14, 12)
    scan:SetScript("OnClick", function() ns.App.Scan() end)

    search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(190, 22)
    search:SetPoint("TOPLEFT", 20, -190)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        panel:Hide()
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        query = self:GetText():lower()
        if self.hint then self.hint:SetShown(query == "") end
        scroll:SetVerticalScroll(0)
        Window.Refresh()
    end)
    search.hint = text(search, "GameFontDisableSmall", T("SEARCH"), 0, -5)
    panel:SetScript("OnHide", function()
        search:ClearFocus()
        GameTooltip:Hide()
    end)

    -- Keep the icon grid outside the settings scroll frame so it cannot scroll or clip.
    gridContent = CreateFrame("Frame", nil, panel)
    -- Explicitly promote the whole hierarchy; a plain child may retain MEDIUM strata.
    gridContent:SetFrameStrata(panel:GetFrameStrata())
    gridContent:SetFrameLevel(panel:GetFrameLevel() + 1)
    gridContent:SetPoint("TOPLEFT", PADDING, -PADDING)
    gridContent:Hide()
    scroll = CreateFrame("ScrollFrame", "CompactAddonButtonsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -228)
    scroll:SetPoint("BOTTOMRIGHT", -30, 52)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(ns.Settings.GetColumns() * CELL, 1)
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
    local locale, revision = ns.Localization.GetLocale(), ns.Localization.GetRevision()
    local preference, columns = ns.Settings.GetLanguage(), ns.Settings.GetColumns()
    local manual = ns.Settings.GetPopupManual()
    local anchor, offset = ns.Settings.GetPopupAnchor(), ns.Settings.GetPopupOffset()
    local changed = locale ~= textLocale or revision ~= textRevision
    if changed then
        title:SetText(T("TITLE"))
        empty:SetText(T("EMPTY"))
        search.hint:SetText(T("SEARCH"))
        scan:SetText(T("SCAN"))
        languageLabel:SetText(T("LANGUAGE"))
        columnsLabel:SetText(T("BUTTONS_PER_ROW"))
        manualLabel:SetText(T("POPUP_MANUAL"))
        anchorLabel:SetText(T("POPUP_ANCHOR"))
        offsetLabel:SetText(T("POPUP_OFFSET"))
    end
    if changed or preference ~= menuPreference then languageDropdown:GenerateMenu() end
    if changed or columns ~= menuColumns then columnsDropdown:GenerateMenu() end
    if changed or anchor ~= menuPopupAnchor then anchorDropdown:GenerateMenu() end
    if manualCheck:GetChecked() ~= manual then manualCheck:SetChecked(manual) end
    anchorDropdown:SetEnabled(manual)
    offsetBox:SetEnabled(manual)
    if tonumber(offsetBox:GetText()) ~= offset then offsetBox:SetText(tostring(offset)) end
    textLocale, textRevision, menuPreference, menuColumns = locale, revision, preference, columns
    menuPopupAnchor = anchor
end
