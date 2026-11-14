local _, ns = ...
local Buttons = {}
ns.Buttons = Buttons
local entries, byButton, byKey = {}, {}, {}

function Buttons.All() return entries end
function Buttons.Find(button) return byButton[button] end
function Buttons.Add(key, label, button)
    if byButton[button] or byKey[key] then return nil end
    local entry = { key = key, label = label, button = button }
    entries[#entries + 1], byButton[button], byKey[key] = entry, entry, entry
    return entry
end
function Buttons.Rename(entry, key, label)
    if byKey[key] and byKey[key] ~= entry then return false end
    byKey[entry.key] = nil
    entry.key, entry.label, byKey[key] = key, label, entry
    return true
end
function Buttons.Sort()
    table.sort(entries, function(a, b)
        if a.label:lower() == b.label:lower() then return a.key < b.key end
        return a.label:lower() < b.label:lower()
    end)
end
function Buttons.Matches(entry, query)
    return query == "" or entry.label:lower():find(query, 1, true) ~= nil
        or entry.key:lower():find(query, 1, true) ~= nil
end
