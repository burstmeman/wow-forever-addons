local _, ns = ...
local Window = {}
ns.Window = Window
local T = ns.Localization.Text
local text, skin, smallButton = ns.Widgets.Text, ns.Widgets.Skin, ns.Widgets.Button
local floor, max = math.floor, math.max
local rows, slots = {}, {}
local panel, content, gridContent, scroll, empty, footer, search, modeButton
local preview, previewEmpty
local header, close, title, languageLabel, languageDropdown
local columnsLabel, columnsDropdown
local manualCheck, manualLabel
local sections, offsets = {}, {}
local settingsMode = false
local query = ""
local textLocale, textRevision, menuPreference, menuColumns
local lastLayout, popupManual, popupAnchor, popupOffsetX, popupOffsetY, popupX, popupY, popupScale
local WIDTH, HEIGHT, CELL = 780, 540, 32
local LEFT_WIDTH, RIGHT_WIDTH = 308, 384
local PADDING = 3

local function savePosition()
    local point, _, relativePoint, x, y = panel:GetPoint()
    ns.Settings.SetPosition(point, relativePoint, x, y)
end

local function rowAt(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    ns.Widgets.Layer(row, content)
    row:SetSize(26, 26)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("TOPLEFT", 30, -2)
    row.label = text(row, "GameFontHighlight", "", 60, -5)
    row.label:SetWidth(RIGHT_WIDTH - 104)
    row.label:SetJustifyH("LEFT")
    row:SetHitRectInsets(0, -(RIGHT_WIDTH - 70), 0, 0)
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

-- Copy the image, never reparent a region owned by another addon.
local function iconRegion(button)
    local candidates = { button.icon, button.Icon, button.GetNormalTexture and button:GetNormalTexture() }
    for index = 1, 3 do
        local candidate = candidates[index]
        local kind = type(candidate)
        if kind == "string" or kind == "number" then return candidate end
        if (kind == "table" or kind == "userdata") and candidate.GetTexture and candidate:GetTexture() then
            return candidate
        end
    end
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and region:GetTexture() then return region end
    end
end

local function refreshRowIcon(row)
    local source = iconRegion(row.entry.button)
    local texture, coords
    if type(source) == "table" or type(source) == "userdata" then
        texture = source:GetTexture()
        coords = table.concat({ source:GetTexCoord() }, ",")
    else
        texture = source or "Interface\\Icons\\INV_Misc_QuestionMark"
        coords = "0,1,0,1"
    end
    if texture ~= row.iconTexture then
        row.icon:SetTexture(texture)
        row.iconTexture = texture
    end
    if coords ~= row.iconCoords then
        if type(source) == "table" or type(source) == "userdata" then
            row.icon:SetTexCoord(source:GetTexCoord())
        else
            row.icon:SetTexCoord(0, 1, 0, 1)
        end
        row.iconCoords = coords
    end
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
    LEFT = { "RIGHT", "LEFT", -6, 0 },
    RIGHT = { "LEFT", "RIGHT", 6, 0 },
    TOP = { "BOTTOM", "TOP", 0, 6 },
    BOTTOM = { "TOP", "BOTTOM", 0, -6 },
}

function Window.PopupPoint(anchor, x, y)
    local spec = POPUP_POINTS[anchor]
    return spec[1], spec[2], spec[3] + x, spec[4] + y
end

function Window.PositionPopup()
    local launcher = ns.MinimapButton.GetFrame()
    if not panel or not launcher then return false end
    local target = settingsMode and preview or panel
    local point, relative, x, y
    if ns.Settings.GetPopupManual() then
        point, relative, x, y = Window.PopupPoint(
            ns.Settings.GetPopupAnchor(),
            ns.Settings.GetPopupOffsetX(),
            ns.Settings.GetPopupOffsetY()
        )
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
    target:ClearAllPoints()
    target:SetPoint(point, launcher, relative, x, y)
    return true
end

local function layout(gridCount)
    panel:SetBackdropColor(0.055, 0.05, 0.045, settingsMode and 0.97 or 0.88)
    header:SetShown(settingsMode)
    close:SetShown(settingsMode)
    search:SetShown(settingsMode)
    modeButton:SetShown(settingsMode)
    footer:SetShown(settingsMode)
    languageLabel:SetShown(settingsMode)
    languageDropdown:SetShown(settingsMode)
    columnsLabel:SetShown(settingsMode)
    columnsDropdown:SetShown(settingsMode)
    manualCheck:SetShown(settingsMode)
    manualLabel:SetShown(settingsMode)
    for _, block in ipairs(sections) do
        block:SetShown(settingsMode)
    end
    scroll:SetShown(settingsMode)
    local target = settingsMode and preview or panel
    if gridContent:GetParent() ~= target then
        gridContent:SetParent(target)
        gridContent:ClearAllPoints()
        gridContent:SetPoint("TOPLEFT", target, "TOPLEFT", PADDING, -PADDING)
        gridContent:SetFrameLevel(target:GetFrameLevel() + 1)
        for _, slot in ipairs(slots) do
            slot:SetFrameLevel(gridContent:GetFrameLevel() + 1)
        end
        for _, entry in ipairs(ns.Buttons.All()) do
            if entry.collected then ns.Collection.Anchor(entry) end
        end
    end
    gridContent:Show()
    preview:SetShown(settingsMode)
    local columns, rows, width, height = Window.GridMetrics(gridCount, ns.Settings.GetColumns())
    target:SetSize(width, height)
    gridContent:SetSize(columns * CELL, rows * CELL)
    previewEmpty:SetShown(settingsMode and gridCount == 0)
    previewEmpty:SetWidth(width - PADDING * 2)
    scroll:ClearAllPoints()
    empty:ClearAllPoints()
    empty:SetParent(settingsMode and sections[3] or panel)
    if settingsMode then
        panel:SetSize(WIDTH, HEIGHT)
        scroll:SetPoint("TOPLEFT", sections[3], "TOPLEFT", 12, -90)
        scroll:SetPoint("BOTTOMRIGHT", sections[3], "BOTTOMRIGHT", -26, 12)
        content:SetWidth(RIGHT_WIDTH - 38)
        empty:SetPoint("TOPLEFT", sections[3], "TOPLEFT", 12, -112)
        empty:SetWidth(RIGHT_WIDTH - 38)
    else
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

local function layoutKey(visible, grid, columns)
    local parts = { settingsMode and "settings" or "grid", tostring(columns), query }
    for index = 1, #visible do
        local entry = visible[index]
        parts[#parts + 1] = entry.key
        parts[#parts + 1] = entry.label
        parts[#parts + 1] = entry.button:IsShown() and "1" or "0"
        parts[#parts + 1] = ns.Settings.IsException(entry.key) and "1" or "0"
    end
    parts[#parts + 1] = "grid"
    for _, entry in ipairs(grid) do
        parts[#parts + 1] = entry.key
    end
    return table.concat(parts, "\n")
end

local function placePopup(force)
    local launcher = ns.MinimapButton.GetFrame()
    local manual = ns.Settings.GetPopupManual()
    local anchor = ns.Settings.GetPopupAnchor()
    local offsetX, offsetY = ns.Settings.GetPopupOffsetX(), ns.Settings.GetPopupOffsetY()
    local x, y, scale
    if launcher then
        x, y = launcher:GetCenter()
        scale = launcher:GetEffectiveScale()
    end
    if
        not force
        and manual == popupManual
        and anchor == popupAnchor
        and offsetX == popupOffsetX
        and offsetY == popupOffsetY
        and x == popupX
        and y == popupY
        and scale == popupScale
    then
        return
    end
    if not Window.PositionPopup() then return end
    popupManual, popupAnchor, popupOffsetX, popupOffsetY, popupX, popupY, popupScale =
        manual, anchor, offsetX, offsetY, x, y, scale
end

function Window.IsShown() return panel ~= nil and panel:IsShown() end
function Window.GetPopupFrame() return settingsMode and preview or panel end

function Window.Refresh(force)
    if not panel or InCombatLockdown() then return end
    Window.RefreshTexts()
    -- Keep labels current, but defer hidden layout work until the next opening.
    if not force and not panel:IsShown() then return end
    local visible, grid = {}, {}
    for _, entry in ipairs(ns.Buttons.All()) do
        if entry.collected and entry.button:IsShown() then grid[#grid + 1] = entry end
        if settingsMode then
            if ns.Buttons.Matches(entry, query) then visible[#visible + 1] = entry end
        elseif entry.collected and entry.button:IsShown() then
            visible[#visible + 1] = entry
        end
    end
    local columns = Window.GridMetrics(#grid, ns.Settings.GetColumns())
    local key = layoutKey(visible, grid, columns)
    if not force and key == lastLayout then
        if settingsMode then
            for _, row in ipairs(rows) do
                if row:IsShown() then refreshRowIcon(row) end
            end
        end
        updateChrome()
        placePopup(false)
        return
    end
    lastLayout = key
    layout(#grid)
    local count, activeSlots = 0, {}
    for _, entry in ipairs(visible) do
        if settingsMode then
            count = count + 1
            local row = rowAt(count)
            row.entry = entry
            refreshRowIcon(row)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(count - 1) * 30)
            row.label:SetText(entry.label)
            row.label:SetTextColor(1, entry.button:IsShown() and 0.95 or 0.6, entry.button:IsShown() and 0.85 or 0.6)
            row:SetChecked(ns.Settings.IsException(entry.key))
            row:Show()
        end
    end
    for index, entry in ipairs(grid) do
        local slot = entry.slot
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", ((index - 1) % columns) * CELL, -floor((index - 1) / columns) * CELL)
        activeSlots[slot] = true
    end
    if not settingsMode then count = #grid end
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

local function section(key, left, top, width, height)
    local block = CreateFrame("Frame", nil, panel)
    ns.Widgets.Layer(block, panel)
    block:SetPoint("TOPLEFT", left, -top)
    block:SetSize(width, height)
    block.titleKey = key
    block.title = text(block, "GameFontNormal", T(key), 0, 0)
    local line = block:CreateTexture(nil, "BACKGROUND")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(0.5, 0.43, 0.3, 0.5)
    line:SetPoint("TOPLEFT", 0, -23)
    line:SetSize(width, 1)
    sections[#sections + 1] = block
    return block
end

local function offsetSlider(parent, axis, top)
    local slider = ns.Widgets.Slider(parent, LEFT_WIDTH - 24)
    slider:SetPoint("TOPLEFT", 12, -top)
    slider.axis = axis
    slider.label = text(parent, "GameFontHighlight", "", 0, -(top - 22))
    slider:SetValue(axis == "X" and ns.Settings.GetPopupOffsetX() or ns.Settings.GetPopupOffsetY())
    slider:SetScript("OnValueChanged", function(self, value)
        local integer = math.floor(value + 0.5)
        if self:GetValue() ~= integer then
            self:SetValue(integer)
            return
        end
        local current = axis == "X" and ns.Settings.GetPopupOffsetX() or ns.Settings.GetPopupOffsetY()
        if integer == current then return end
        if axis == "X" then
            ns.App.SetPopup(nil, integer, nil)
        else
            ns.App.SetPopup(nil, nil, integer)
        end
    end)
    offsets[#offsets + 1] = slider
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

    -- Reuse the real icon grid while the owner remains the settings window.
    -- Parenting the preview to it also closes both windows through Escape.
    preview = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    preview:SetFrameStrata(panel:GetFrameStrata())
    preview:SetFrameLevel(panel:GetFrameLevel() + 1)
    preview:SetClampedToScreen(true)
    preview:EnableMouse(true)
    skin(preview)
    preview:SetBackdropColor(0.055, 0.05, 0.045, 0.88)
    preview:Hide()
    previewEmpty = text(preview, "GameFontDisable", T("EMPTY"), 0, 0)
    previewEmpty:ClearAllPoints()
    previewEmpty:SetPoint("CENTER", preview, "CENTER", 0, 0)

    header = CreateFrame("Frame", nil, panel)
    ns.Widgets.Layer(header, panel)
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
    ns.Widgets.Layer(close, panel)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() panel:Hide() end)

    local general = section("SECTION_GENERAL", 24, 58, LEFT_WIDTH, 144)
    local position = section("SECTION_POSITION", 24, 226, LEFT_WIDTH, 228)
    local buttons = section("SECTION_BUTTONS", 372, 58, RIGHT_WIDTH, HEIGHT - 106)
    local divider = buttons:CreateTexture(nil, "BACKGROUND")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(0.5, 0.43, 0.3, 0.5)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 350, -58)
    divider:SetSize(1, HEIGHT - 106)

    languageLabel = text(general, "GameFontHighlight", T("LANGUAGE"), 0, -36)
    languageDropdown =
        CreateFrame("DropdownButton", "CompactAddonButtonsLanguage", general, "WowStyle1DropdownTemplate")
    ns.Widgets.Layer(languageDropdown, general)
    languageDropdown:SetPoint("TOPLEFT", 0, -54)
    languageDropdown:SetWidth(LEFT_WIDTH)
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

    columnsLabel = text(general, "GameFontHighlight", T("BUTTONS_PER_ROW"), 0, -92)
    columnsDropdown = CreateFrame("DropdownButton", "CompactAddonButtonsColumns", general, "WowStyle1DropdownTemplate")
    ns.Widgets.Layer(columnsDropdown, general)
    columnsDropdown:SetPoint("TOPLEFT", 0, -110)
    columnsDropdown:SetWidth(LEFT_WIDTH)
    columnsDropdown:SetupMenu(function(_, root)
        local function selected(value) return ns.Settings.GetColumns() == value end
        local function choose(value) ns.App.SetColumns(value) end
        for value = ns.Settings.MIN_COLUMNS, ns.Settings.MAX_COLUMNS do
            root:CreateRadio(tostring(value), selected, choose, value)
        end
    end)

    manualCheck = CreateFrame("CheckButton", "CompactAddonButtonsPopupManual", position, "UICheckButtonTemplate")
    ns.Widgets.Layer(manualCheck, position)
    manualCheck:SetSize(26, 26)
    manualCheck:SetPoint("TOPLEFT", 0, -36)
    manualCheck:SetChecked(ns.Settings.GetPopupManual())
    manualCheck:SetScript("OnClick", function(self) ns.App.SetPopupManual(self:GetChecked()) end)
    manualLabel = text(position, "GameFontHighlight", T("POPUP_MANUAL"), 30, -42)
    manualLabel:SetWidth(LEFT_WIDTH - 30)
    offsetSlider(position, "X", 100)
    offsetSlider(position, "Y", 170)

    modeButton = smallButton(panel, T("SETTINGS"), 108)
    modeButton:SetPoint("BOTTOMLEFT", 16, 12)
    modeButton:SetScript("OnClick", function() setMode(not settingsMode) end)

    search = CreateFrame("EditBox", nil, buttons, "InputBoxTemplate")
    ns.Widgets.Layer(search, buttons)
    search:SetSize(RIGHT_WIDTH - 20, 22)
    search:SetPoint("TOPLEFT", 8, -58)
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
        preview:Hide()
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
    scroll = CreateFrame("ScrollFrame", "CompactAddonButtonsScroll", buttons, "UIPanelScrollFrameTemplate")
    ns.Widgets.Layer(scroll, buttons)
    scroll:SetPoint("TOPLEFT", 16, -228)
    scroll:SetPoint("BOTTOMRIGHT", -30, 52)
    content = CreateFrame("Frame", nil, scroll)
    ns.Widgets.Layer(content, scroll)
    content:SetSize(ns.Settings.GetColumns() * CELL, 1)
    scroll:SetScrollChild(content)
    empty = text(panel, "GameFontDisable", T("EMPTY"), 24, -130)
    empty:SetWidth(330)
    empty:SetJustifyH("CENTER")
    footer = text(buttons, "GameFontDisableSmall", T("HINT"), 0, -32)
    footer:SetWidth(RIGHT_WIDTH)
    footer:SetJustifyH("LEFT")
end

function Window.GetFrame() return panel end
function Window.RefreshTexts()
    if not panel then return end
    local locale, revision = ns.Localization.GetLocale(), ns.Localization.GetRevision()
    local preference, columns = ns.Settings.GetLanguage(), ns.Settings.GetColumns()
    local manual = ns.Settings.GetPopupManual()
    local changed = locale ~= textLocale or revision ~= textRevision
    if changed then
        title:SetText(T("TITLE"))
        empty:SetText(T("EMPTY"))
        previewEmpty:SetText(T("EMPTY"))
        search.hint:SetText(T("SEARCH"))
        languageLabel:SetText(T("LANGUAGE"))
        columnsLabel:SetText(T("BUTTONS_PER_ROW"))
        manualLabel:SetText(T("POPUP_MANUAL"))
        for _, block in ipairs(sections) do
            block.title:SetText(T(block.titleKey))
        end
    end
    if changed or preference ~= menuPreference then languageDropdown:GenerateMenu() end
    if changed or columns ~= menuColumns then columnsDropdown:GenerateMenu() end
    if manualCheck:GetChecked() ~= manual then manualCheck:SetChecked(manual) end
    for _, slider in ipairs(offsets) do
        local value = slider.axis == "X" and ns.Settings.GetPopupOffsetX() or ns.Settings.GetPopupOffsetY()
        if slider:GetValue() ~= value then slider:SetValue(value) end
        if slider:IsEnabled() ~= manual then
            slider:SetEnabled(manual)
            slider.label:SetTextColor(manual and 0.95 or 0.5, manual and 0.95 or 0.5, manual and 0.95 or 0.5)
        end
        writeText(slider.label, T("POPUP_OFFSET_" .. slider.axis) .. ": " .. tostring(value))
    end
    textLocale, textRevision, menuPreference, menuColumns = locale, revision, preference, columns
end
