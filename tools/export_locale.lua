-- Prints one language's strings the way CurseForge's translation tool imports them:
--
--   lua5.1 tools/export_locale.lua <locale>
--
-- One `L["KEY"] = "text"` line per string, sorted by key. enUS prints the English that defines
-- every phrase; any other locale prints this repository's draft translation for it.
-- tools/upload_translations.sh sends the result to CurseForge.

local here = (arg and arg[0] or "tools/export_locale.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = os.getenv("LTM_ADDON_DIR") or (here .. "/..")

local locale = arg and arg[1]
if not (locale and locale:match("^%l%l%u%u$")) then
    io.stderr:write("usage: export_locale.lua <locale, e.g. enUS or deDE>\n")
    os.exit(2)
end

-- Locales.lua needs nothing from the client but GetLocale and the namespace every addon file
-- is handed, so it runs in a sandbox rather than against stand-in globals.
local chunk = assert(loadfile(ROOT .. "/Locales.lua"))
setfenv(chunk, setmetatable({ GetLocale = function() return locale end }, { __index = _G }))
local namespace = {}
chunk("LootToastMover", namespace)

local strings = namespace.L
local source = getmetatable(strings).__index
if locale ~= "enUS" then
    source = {}
    for key, text in pairs(strings) do source[key] = text end
    if next(source) == nil then
        io.stderr:write(("export_locale.lua: there are no %s translations to export\n"):format(locale))
        os.exit(1)
    end
end

local keys = {}
for key in pairs(source) do table.insert(keys, key) end
table.sort(keys)

for _, key in ipairs(keys) do
    local text = source[key]
    -- A line break might not survive CurseForge's import, so none is allowed through.
    if text:find("[\r\n]") then
        io.stderr:write(("export_locale.lua: %s %s has a line break\n"):format(locale, key))
        os.exit(1)
    end
    local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"')
    io.write(('L["%s"] = "%s"\n'):format(key, escaped))
end
