local _, ns = ...
local Widgets = {}
ns.Widgets = Widgets

function Widgets.Text(parent, font, value, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(value)
    return label
end
function Widgets.Skin(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    frame:SetBackdropColor(0.055, 0.05, 0.045, 0.97)
    frame:SetBackdropBorderColor(0.40, 0.33, 0.21, 0.95)
end
function Widgets.Button(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    return button
end
