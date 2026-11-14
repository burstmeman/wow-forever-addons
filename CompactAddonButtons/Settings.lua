local _, ns = ...
local Settings = {}
ns.Settings = Settings
local db
local anchors = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function validPosition(position)
    return type(position) == "table" and anchors[position[1]] and anchors[position[2]]
        and finite(position[3]) and finite(position[4])
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
    db.version = 2
end

function Settings.GetAngle() return db.angle end
function Settings.SetAngle(value) if finite(value) then db.angle = value % 360 end end
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
