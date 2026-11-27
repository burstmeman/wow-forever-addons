local _, ns = ...
local Widgets = {}
ns.Widgets = Widgets

function Widgets.Layer(frame, parent)
    frame:SetFrameStrata(parent:GetFrameStrata())
    frame:SetFrameLevel(parent:GetFrameLevel() + 1)
end

function Widgets.Text(parent, font, value, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(value)
    label:SetJustifyH("LEFT")
    return label
end

function Widgets.Slider(parent, width)
    local slider = CreateFrame("Slider", nil, parent)
    Widgets.Layer(slider, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetSize(width, 16)
    slider:SetMinMaxValues(ns.Settings.MIN_POPUP_OFFSET, ns.Settings.MAX_POPUP_OFFSET)
    slider:SetValueStep(1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(24, 24)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\WHITE8X8")
    track:SetSize(width, 3)
    track:SetPoint("CENTER", slider, "CENTER", 0, 0)
    local minimum = Widgets.Text(slider, "GameFontDisableSmall", tostring(ns.Settings.MIN_POPUP_OFFSET), 0, -18)
    minimum:SetWidth(width / 2)
    local maximum = Widgets.Text(slider, "GameFontDisableSmall", tostring(ns.Settings.MAX_POPUP_OFFSET), 0, -18)
    maximum:ClearAllPoints()
    maximum:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maximum:SetJustifyH("RIGHT")
    return slider
end
function Widgets.Skin(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.055, 0.05, 0.045, 0.97)
    frame:SetBackdropBorderColor(0.40, 0.33, 0.21, 0.95)
end
function Widgets.Button(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    Widgets.Layer(button, parent)
    button:SetSize(width, 22)
    button:SetText(label)
    return button
end
