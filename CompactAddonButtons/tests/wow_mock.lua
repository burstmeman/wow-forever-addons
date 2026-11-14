local combat, frames = false, {}
local methods = {}
local function noop() end
for _, method in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag",
    "RegisterForClicks", "SetHighlightTexture", "SetTexture", "SetTexCoord", "SetJustifyH",
    "SetHitRectInsets", "SetTextColor", "SetAutoFocus", "SetMaxLetters", "SetOwner", "AddLine",
    "StartMoving", "StopMovingOrSizing" }) do methods[method] = noop end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:GetChildren()
    local result = {}
    for _, frame in ipairs(frames) do if frame.parent == self then result[#result + 1] = frame end end
    return unpack(result)
end
function methods:IsObjectType(kind)
    return self.kind == kind or (kind == "Frame" and self.kind ~= "Texture" and self.kind ~= "FontString")
end
function methods:IsProtected() return self.protected end
function methods:SetParent(parent) self.parent = parent end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function methods:GetNumPoints() return #self.points end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetFrameLevel(level) self.frameLevel = level end
function methods:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel() + 1) or 0 end
function methods:SetFrameStrata(strata) self.frameStrata = strata end
function methods:GetFrameStrata() return self.frameStrata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetCenter() return self.centerX or 200, self.centerY or 200 end
function methods:GetNormalTexture() return self.texture end
function methods:GetRegions() return unpack(self.regions or {}) end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:Show() self.shown = true end
function methods:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetText(value) self.value = value end
function methods:GetText() return self.value or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:ClearFocus() self.focus = false end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetScrollChild(child) self.child = child end

function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, points = {},
        scripts = {}, events = {}, shown = true, width = 100, height = 100 }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
GetLocale = function() return TEST_LOCALE end
InCombatLockdown = function() return combat end
tinsert = table.insert
UISpecialFrames, SlashCmdList = {}, {}
UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
MinimapBackdrop = CreateFrame("Frame", "MinimapBackdrop", UIParent)
GameTooltip = CreateFrame("Frame", "GameTooltip", UIParent)
GetCursorPosition = function() return 250, 200 end
math.atan2 = math.atan2 or function(y, x) return math.atan(y / x) end


TestUI = { frames = frames, SetCombat = function(value) combat = value end }

function methods:SetupMenu(builder) self.menuBuilder = builder end
function methods:GenerateMenu()
    local owner = self
    self.choices = {}
    local menu = {}
    function menu:CreateRadio(label, selected, choose, value)
        local choice = { label = label, selected = selected, choose = choose, value = value }
        function choice:SetEnabled(enabled) self.enabled = enabled end
        owner.choices[#owner.choices + 1] = choice
        if selected(value) then owner.selectedText = label end
        return choice
    end
    self.menuBuilder(self, menu)
end
