local _, ns = ...
local Localization = {}
ns.Localization = Localization
local packs, order, aliases = {}, {}, {}
local active, preference, clientLocale = "enUS", "auto", "enUS"
local onChanged

function Localization.IsSupported(locale)
    return packs[aliases[locale] or locale] ~= nil
end

function Localization.Resolve(requested, client)
    local locale = requested == "auto" and client or requested
    locale = aliases[locale] or locale
    return packs[locale] and locale or "enUS"
end

function Localization.Use(requested, client)
    preference, clientLocale = requested or "auto", client or clientLocale
    active = Localization.Resolve(preference, clientLocale)
    if onChanged then onChanged() end
end

function Localization.Register(locale, name, translations, localeAliases)
    if type(locale) ~= "string" or locale == "" or locale == "auto"
        or type(name) ~= "string" or name == "" or type(translations) ~= "table" then return false end
    if localeAliases ~= nil and type(localeAliases) ~= "table" then return false end
    for key, value in pairs(translations) do
        if type(key) ~= "string" or type(value) ~= "string" then return false end
    end
    for _, alias in ipairs(localeAliases or {}) do
        if type(alias) ~= "string" or alias == "" or alias == "auto" then return false end
    end
    if not packs[locale] then
        packs[locale] = { locale = locale, name = name, strings = {} }
        order[#order + 1] = locale
    end
    local pack = packs[locale]
    pack.name = name
    for key, value in pairs(translations) do pack.strings[key] = value end
    for _, alias in ipairs(localeAliases or {}) do aliases[alias] = locale end
    active = Localization.Resolve(preference, clientLocale)
    if onChanged then onChanged() end
    return true
end

function Localization.Text(key)
    local selected, english = packs[active], packs.enUS
    return (selected and selected.strings[key]) or (english and english.strings[key]) or key
end

function Localization.GetLocale() return active end
function Localization.GetLanguages()
    local result = {}
    for _, locale in ipairs(order) do
        result[#result + 1] = { locale = locale, name = packs[locale].name }
    end
    return result
end
function Localization.SetOnChanged(callback) onChanged = callback end
