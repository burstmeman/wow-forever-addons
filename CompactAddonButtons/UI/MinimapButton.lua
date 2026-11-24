local addonName, ns = ...
local MinimapButton = {}
ns.MinimapButton = MinimapButton
local T, max = ns.Localization.Text, math.max
local launcher

local rounded = {
    ROUND = { true, true, true, true },
    SQUARE = {},
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

function MinimapButton.GetFrame() return launcher end
function MinimapButton.StopDragging()
    if launcher then launcher:SetScript("OnUpdate", nil) end
end

function MinimapButton.Position()
    local angle = math.rad(ns.Settings.GetAngle())
    local radiusX, radiusY = Minimap:GetWidth() / 2 + 7, Minimap:GetHeight() / 2 + 7
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadrant = (x < 0 and 1 or 0) + (y > 0 and 2 or 0) + 1
    if rounded[shape] and not rounded[shape][quadrant] then
        local divisor = max(math.abs(x), math.abs(y))
        x, y = x / divisor, y / divisor
    end
    launcher:ClearAllPoints()
    launcher:SetPoint("CENTER", Minimap, "CENTER", x * radiusX, y * radiusY)
end

function MinimapButton.Create()
    local button = CreateFrame("Button", "CompactAddonButtonsMinimapButton", Minimap)
    launcher = button
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
    icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\MinimapIcon")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0, 1, 0, 1)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(_, mouse) ns.App.Toggle(mouse == "RightButton") end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(T("MINIMAP_TITLE"), 1, 0.82, 0)
        GameTooltip:AddLine(T("LEFT_CLICK"), 1, 1, 1)
        GameTooltip:AddLine(T("RIGHT_CLICK"), 1, 1, 1)
        GameTooltip:AddLine(T("DRAG"), 0.65, 0.65, 0.65)
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
            ns.Settings.SetAngle(math.deg(math.atan2(y / scale - centerY, x / scale - centerX)))
            MinimapButton.Position()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    Minimap:HookScript("OnSizeChanged", function()
        if not InCombatLockdown() then MinimapButton.Position() end
    end)
    MinimapButton.Position()
end
