-- Load Settings independently so migration cases cannot alter the running UI.
local current, legacy = CompactAddonButtonsDB, BetterAddonButtonsDB
local loadSettings = assert(loadfile(ADDON_PATH .. "/Settings.lua"))
local directions = {
    LEFT = { -1, 0 },
    RIGHT = { 1, 0 },
    TOP = { 0, 1 },
    BOTTOM = { 0, -1 },
    TOPLEFT = { -1, 1 },
    TOPRIGHT = { 1, 1 },
    BOTTOMLEFT = { -1, -1 },
    BOTTOMRIGHT = { 1, -1 },
}
for anchor, direction in pairs(directions) do
    for _, gap in ipairs({ 0, 6, 200 }) do
        local old = { popupManual = true, popupAnchor = anchor, popupOffset = gap, exceptions = { example = true } }
        CompactAddonButtonsDB, BetterAddonButtonsDB = nil, old
        local sandbox = {}
        loadSettings("CompactAddonButtons", sandbox)
        local settings = sandbox.Settings
        settings.Initialize()
        local side = settings.GetPopupAnchor()
        assert(side == "LEFT" or side == "RIGHT" or side == "TOP" or side == "BOTTOM")
        local base = directions[side]
        assert(settings.GetPopupOffsetX() == direction[1] * gap - base[1] * 6)
        assert(settings.GetPopupOffsetY() == direction[2] * gap - base[2] * 6)
        assert(CompactAddonButtonsDB == old and old.exceptions.example and old.popupOffset == gap)
        assert(settings.GetPopupManual() and BetterAddonButtonsDB == nil and old.version == 3)
        assert(settings.SetPopup("BOTTOM", -255, 256))
        settings.Initialize()
        assert(
            settings.GetPopupAnchor() == "BOTTOM"
                and settings.GetPopupOffsetX() == -255
                and settings.GetPopupOffsetY() == 256
        )
        assert(not settings.SetPopup("LEFT", 257, 0))
        assert(settings.GetPopupAnchor() == "BOTTOM", "invalid axis updates must be atomic")
    end
end
CompactAddonButtonsDB = { popupOffsetX = false, popupOffsetY = 10, popupAnchor = "invalid", popupManual = "true" }
local sandbox = {}
loadSettings("CompactAddonButtons", sandbox)
sandbox.Settings.Initialize()
assert(sandbox.Settings.GetPopupOffsetX() == 0 and sandbox.Settings.GetPopupOffsetY() == 10)
assert(not sandbox.Settings.GetPopupManual() and sandbox.Settings.GetPopupAnchor() == "LEFT")
CompactAddonButtonsDB, BetterAddonButtonsDB = current, legacy
