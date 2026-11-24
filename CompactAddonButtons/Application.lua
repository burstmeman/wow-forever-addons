local _, ns = ...
local App = {}
ns.App = App
local ready, initialized, pending = false, false, false
local orderDirty, scanChanged = false, false

local function sortButtons()
    if not orderDirty then return end
    ns.Buttons.Sort()
    orderDirty = false
end

local function register(key, label, button)
    local existing = ns.Buttons.Find(button)
    if existing then
        -- A button found before LibDBIcon loads keeps a frame: key. When the
        -- library appears, adopt its lib: key and move the saved exception with it.
        if existing.key:find("^frame:") and key:find("^lib:") then
            local oldKey = existing.key
            if ns.Buttons.Rename(existing, key, label) then
                ns.Settings.RenameException(oldKey, key)
                orderDirty = true
                return true
            end
        end
        return false
    end
    if ns.Discovery.IsExcluded(button) then return false end
    local entry = ns.Buttons.Add(key, label, button)
    if not entry then return false end
    orderDirty = true
    ns.Collection.Watch(entry)
    return true
end

function App.IsReady() return ready end
function App.IsPending() return pending end
function App.Initialize()
    if initialized then return end
    ns.Settings.Initialize()
    ns.Localization.Use(ns.Settings.GetLanguage(), GetLocale())
    ns.Localization.SetOnChanged(function()
        if ready then ns.Window.Refresh() end
    end)
    initialized = true
end

function App.Apply()
    if not ready then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    for _, entry in ipairs(ns.Buttons.All()) do
        if ns.Settings.IsException(entry.key) then
            ns.Collection.Release(entry)
        else
            ns.Collection.Collect(entry, ns.Window.CreateSlot)
        end
    end
    ns.Window.Refresh()
end

local function noteDiscovered(key, label, button)
    if register(key, label, button) then scanChanged = true end
end

function App.Scan()
    if not ready then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    scanChanged = false
    ns.Discovery.Scan(noteDiscovered)
    sortButtons()
    -- Opening the window refreshes it. A closed window only needs Collect when
    -- discovery changed the catalog or combat deferred a parent change. Text
    -- still follows language changes while the window is hidden.
    if scanChanged or pending or ns.Window.IsShown() then
        App.Apply()
    else
        ns.Window.Refresh()
    end
end

function App.Start()
    if ready then return end
    App.Initialize()
    ns.Window.Create()
    ns.MinimapButton.Create()
    ready = true
    App.Scan()
end

function App.Toggle(settings)
    if not ready then return end
    if InCombatLockdown() then
        print("|cffffd100CompactAddonButtons:|r " .. ns.Localization.Text("LOCKED"))
        return
    end
    App.Scan()
    ns.Window.Toggle(settings == true)
end

function App.SetException(key, enabled)
    ns.Settings.SetException(key, enabled)
    App.Apply()
end

function App.SetLanguage(locale)
    if not initialized or (locale ~= "auto" and not ns.Localization.IsSupported(locale)) then return false end
    local preference = locale == "auto" and "auto" or ns.Localization.Resolve(locale)
    ns.Settings.SetLanguage(preference)
    ns.Localization.Use(preference)
    return true
end

function App.SetColumns(value)
    if not ns.Settings.SetColumns(value) then return false end
    App.Apply()
    return true
end

function App.RegisterButton(key, label, button)
    local buttonType = type(button)
    if
        type(key) ~= "string"
        or key == ""
        or (buttonType ~= "table" and buttonType ~= "userdata")
        or type(button.GetName) ~= "function"
        or type(button.IsObjectType) ~= "function"
        or not button:IsObjectType("Frame")
    then
        return false
    end
    if label ~= nil and (type(label) ~= "string" or label == "") then return false end
    local added = register("custom:" .. key, label or key, button)
    if added and ready then
        sortButtons()
        App.Apply()
    end
    return added
end

function App.OnCombatStart()
    if not ready then return end
    ns.Window.Close()
    ns.MinimapButton.StopDragging()
end

function App.OnCombatEnd()
    if not ready then return end
    App.Scan()
    ns.MinimapButton.Position()
end
