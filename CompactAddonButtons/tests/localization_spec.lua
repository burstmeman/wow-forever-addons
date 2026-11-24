local ns = TestUI.ns
local L, Settings = ns.Localization, ns.Settings
local expected = {
    enUS = "enUS",
    enGB = "enUS",
    ruRU = "ruRU",
    esES = "esES",
    esMX = "esES",
    deDE = "deDE",
    frFR = "frFR",
    koKR = "enUS",
}
assert(Settings.GetLanguage() == "auto")
assert(CompactAddonButtons.GetLanguage() == expected[TEST_LOCALE])
assert(#L.GetLanguages() == 5)

-- The menu invokes the real application use case and refreshes existing widgets.
ns.App.Toggle(true)
local dropdown = CompactAddonButtonsLanguage
assert(dropdown:IsShown() and #dropdown.choices == 6)
local german
for _, choice in ipairs(dropdown.choices) do
    if choice.value == "deDE" then german = choice end
end
assert(german)
german.choose(german.value)
assert(Settings.GetLanguage() == "deDE" and CompactAddonButtons.GetLanguage() == "deDE")
assert(dropdown.selectedText == "Deutsch")

local search
for _, frame in ipairs(TestUI.frames) do
    if frame.kind == "EditBox" then search = frame end
end
assert(search.hint:GetText() == "Schaltfläche suchen...")
for _, language in ipairs(L.GetLanguages()) do
    assert(CompactAddonButtons.SetLanguage(language.locale))
    assert(CompactAddonButtons.GetLanguage() == language.locale)
    assert(search.hint:GetText() == L.Text("SEARCH"), "existing widgets translate immediately")
    assert(dropdown.selectedText == language.name)
end
assert(CompactAddonButtons.SetLanguage("esMX"))
assert(Settings.GetLanguage() == "esES" and dropdown.selectedText == "Español")
assert(not CompactAddonButtons.SetLanguage("invalid"))
assert(not CompactAddonButtons.SetLanguage(nil))
assert(Settings.GetLanguage() == "esES", "invalid choices must not alter saved preference")
assert(CompactAddonButtons.SetLanguage("auto"))
assert(CompactAddonButtons.GetLanguage() == expected[TEST_LOCALE])
assert(dropdown.selectedText == L.Text("AUTO_LANGUAGE"))

-- Every shipped language supplies every English key, without accidentally
-- passing this assertion through the runtime English fallback.
for _, language in ipairs(L.GetLanguages()) do
    local english, translated
    local sandbox = {
        Localization = {
            Register = function(locale, name, strings)
                if locale == "enUS" then
                    english = strings
                else
                    translated = strings
                end
            end,
        },
    }
    assert(loadfile(ADDON_PATH .. "/Locales/enUS.lua"))("CompactAddonButtons", sandbox)
    if language.locale ~= "enUS" then
        assert(loadfile(ADDON_PATH .. "/Locales/" .. language.locale .. ".lua"))("CompactAddonButtons", sandbox)
        for key in pairs(english) do
            assert(type(translated[key]) == "string" and translated[key] ~= "", language.locale .. ": " .. key)
        end
    end
end

-- Partial third-party translations fall back per key; packs are copied on registration.
local englishSearch = "Find a button..."
local custom = { TITLE = "Custom buttons" }
assert(CompactAddonButtons.RegisterLocale("xxXX", "Example", custom))
custom.TITLE = "Unexpected mutation"
assert(CompactAddonButtons.SetLanguage("xxXX"))
assert(L.Text("TITLE") == "Custom buttons" and L.Text("SEARCH") == englishSearch)
assert(L.Text("UNKNOWN_TRANSLATION_KEY") == "UNKNOWN_TRANSLATION_KEY")
assert(CompactAddonButtons.RegisterLocale("xxXX", "Example", { SEARCH = "Custom search" }))
assert(L.Text("TITLE") == "Custom buttons" and L.Text("SEARCH") == "Custom search")
assert(search.hint:GetText() == "Custom search", "late registration updates the current UI")
assert(#L.GetLanguages() == 6, "registering more strings must not duplicate languages")
assert(not CompactAddonButtons.RegisterLocale("bad", "Bad", { TITLE = 42 }))
assert(not CompactAddonButtons.RegisterLocale("bad", "Bad", {}, { false }))
assert(not L.IsSupported("bad"), "invalid registration must be atomic")

local languages = L.GetLanguages()
languages[1].name = "Mutated"
assert(L.GetLanguages()[1].name == "English", "callers cannot mutate language metadata")

-- Unsupported saved locales stay recoverable when a pack is installed later.
L.Use("itIT", TEST_LOCALE)
assert(L.GetLocale() == "enUS")
assert(CompactAddonButtons.RegisterLocale("itIT", "Italiano", { TITLE = "Pulsanti addon" }))
assert(L.GetLocale() == "itIT")
assert(L.Text("TITLE") == "Pulsanti addon" and L.Text("SEARCH") == englishSearch)

-- Manual selection survives loading saved settings and ignores the client language.
assert(CompactAddonButtons.SetLanguage("frFR"))
Settings.Initialize()
L.Use(Settings.GetLanguage(), TEST_LOCALE)
assert(L.GetLocale() == "frFR" and Settings.GetLanguage() == "frFR")
local frameCount = #TestUI.frames
ns.App.Start()
assert(#TestUI.frames == frameCount, "duplicate login must not recreate the UI")
assert(not CompactAddonButtons.RegisterButton("invalid", "Invalid", 42))
assert(not CompactAddonButtons.RegisterButton("invalid", "Invalid", GameTooltip:CreateFontString()))

-- Language preference can change during combat without moving protected UI.
TestUI.SetCombat(true)
ns.App.OnCombatStart()
assert(CompactAddonButtons.SetLanguage("deDE"))
assert(Settings.GetLanguage() == "deDE" and not ns.Window.GetFrame():IsShown())
TestUI.SetCombat(false)
ns.App.OnCombatEnd()
assert(search.hint:GetText() == "Schaltfläche suchen...")
