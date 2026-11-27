local _, ns = ...
local Settings = {}
ns.Settings = Settings
Settings.MIN_COLUMNS, Settings.MAX_COLUMNS = 1, 12
Settings.MIN_POPUP_OFFSET, Settings.MAX_POPUP_OFFSET = -255, 256
Settings.POPUP_ANCHORS = {
    "LEFT",
    "RIGHT",
    "TOP",
    "BOTTOM",
}
local db
local legacyDirections = {
    LEFT = { -1, 0 },
    RIGHT = { 1, 0 },
    TOP = { 0, 1 },
    BOTTOM = { 0, -1 },
    TOPLEFT = { -1, 1 },
    TOPRIGHT = { 1, 1 },
    BOTTOMLEFT = { -1, -1 },
    BOTTOMRIGHT = { 1, -1 },
}
local popupAnchors = {}
for _, name in ipairs(Settings.POPUP_ANCHORS) do
    popupAnchors[name] = true
end
local anchors = {
    CENTER = true,
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end

local function validPosition(position)
    return type(position) == "table"
        and anchors[position[1]]
        and anchors[position[2]]
        and finite(position[3])
        and finite(position[4])
end

local function validColumns(value)
    return finite(value)
        and value == math.floor(value)
        and value >= Settings.MIN_COLUMNS
        and value <= Settings.MAX_COLUMNS
end

local function validOffset(value)
    return finite(value)
        and value == math.floor(value)
        and value >= Settings.MIN_POPUP_OFFSET
        and value <= Settings.MAX_POPUP_OFFSET
end

function Settings.Initialize()
    if type(CompactAddonButtonsDB) ~= "table" and type(BetterAddonButtonsDB) == "table" then
        CompactAddonButtonsDB = BetterAddonButtonsDB
    end
    BetterAddonButtonsDB = nil
    if type(CompactAddonButtonsDB) ~= "table" then CompactAddonButtonsDB = {} end
    db = CompactAddonButtonsDB
    if type(db.exceptions) ~= "table" then db.exceptions = {} end
    if not finite(db.angle) then db.angle = 220 end
    if not validPosition(db.position) then db.position = { "CENTER", "CENTER", 0, 0 } end
    if type(db.language) ~= "string" then db.language = "auto" end
    if not validColumns(db.columns) then db.columns = 6 end
    -- Preserve old placement data while migrating the one-axis gap to independent offsets.
    if db.popupManual ~= true then db.popupManual = false end
    local oldDirection = legacyDirections[db.popupAnchor] or legacyDirections.LEFT
    if not popupAnchors[db.popupAnchor] then db.popupAnchor = oldDirection[1] == 1 and "RIGHT" or "LEFT" end
    local direction = legacyDirections[db.popupAnchor]
    local gap = finite(db.popupOffset)
            and db.popupOffset >= 0
            and db.popupOffset <= 200
            and db.popupOffset == math.floor(db.popupOffset)
            and db.popupOffset
        or 6
    if db.popupOffsetX == nil then db.popupOffsetX = oldDirection[1] * gap - direction[1] * 6 end
    if db.popupOffsetY == nil then db.popupOffsetY = oldDirection[2] * gap - direction[2] * 6 end
    if not validOffset(db.popupOffsetX) then db.popupOffsetX = 0 end
    if not validOffset(db.popupOffsetY) then db.popupOffsetY = 0 end
    db.version = 3
end

function Settings.GetAngle() return db.angle end
function Settings.SetAngle(value)
    if finite(value) then db.angle = value % 360 end
end
function Settings.GetPosition() return unpack(db.position) end
function Settings.SetPosition(point, relativePoint, x, y)
    local position = { point, relativePoint, x, y }
    if validPosition(position) then db.position = position end
end
function Settings.IsException(key) return db.exceptions[key] == true end
function Settings.SetException(key, enabled) db.exceptions[key] = enabled and true or nil end
function Settings.RenameException(oldKey, newKey)
    if db.exceptions[oldKey] then db.exceptions[newKey] = true end
    db.exceptions[oldKey] = nil
end
function Settings.GetLanguage() return db.language end
function Settings.SetLanguage(locale) db.language = locale end
function Settings.GetColumns() return db.columns end
function Settings.SetColumns(value)
    if not validColumns(value) then return false end
    db.columns = value
    return true
end
function Settings.GetPopupManual() return db.popupManual == true end
function Settings.SetPopupManual(enabled)
    db.popupManual = enabled and true or false
    return true
end
function Settings.GetPopupAnchor() return db.popupAnchor end
function Settings.GetPopupOffsetX() return db.popupOffsetX end
function Settings.GetPopupOffsetY() return db.popupOffsetY end
function Settings.SetPopup(anchor, x, y)
    if anchor ~= nil and not popupAnchors[anchor] then return false end
    if x ~= nil and not validOffset(x) then return false end
    if y ~= nil and not validOffset(y) then return false end
    if anchor == nil and x == nil and y == nil then return false end
    if anchor ~= nil then db.popupAnchor = anchor end
    if x ~= nil then db.popupOffsetX = x end
    if y ~= nil then db.popupOffsetY = y end
    return true
end
