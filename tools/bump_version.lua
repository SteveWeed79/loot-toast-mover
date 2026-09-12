-- Bumps the addon's patch version and records it in the changelog.
--
--   lua5.1 tools/bump_version.lua "Reason for the release"
--
-- Prints the new version to stdout. Intended for the scheduled interface-bump workflow,
-- which runs it only after the TOC's Interface version actually changed, but it is safe to
-- run by hand.
--
-- Three places have to move together or tests/check_toc.lua fails the build:
--   * ## Version in LootToastMover.toc
--   * the vX.Y.Z banner at the top of LootToastMover.lua
--   * a CHANGELOG.md entry for the new version

local here = (arg and arg[0] or "tools/bump_version.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = os.getenv("LTM_ADDON_DIR") or (here .. "/..")

local TOC = ROOT .. "/LootToastMover.toc"
local LUA = ROOT .. "/LootToastMover.lua"
local CHANGELOG = ROOT .. "/CHANGELOG.md"

local reason = arg and arg[1]

local function read(path)
    local fh = assert(io.open(path), "cannot open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local function write(path, text)
    local fh = assert(io.open(path, "w"), "cannot write " .. path)
    fh:write(text)
    fh:close()
end

--- "120105" -> "12.1.5". The last two digits are the patch, the two before that the minor,
--- and whatever remains the major.
local function gameVersion(interface)
    local digits = tostring(interface)
    local patch = tonumber(digits:sub(-2))
    local minor = tonumber(digits:sub(-4, -3))
    local major = tonumber(digits:sub(1, -5))
    if not (major and minor and patch) then return nil end
    return ("%d.%d.%d"):format(major, minor, patch)
end

local toc = read(TOC)

local version = toc:match("##%s*Version:%s*([%d%.]+)")
assert(version, "no ## Version in the TOC")
local interface = toc:match("##%s*Interface:%s*(%d+)")
assert(interface, "no ## Interface in the TOC")

local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
assert(major, "## Version is not a three-part version: " .. version)
local newVersion = ("%s.%s.%d"):format(major, minor, tonumber(patch) + 1)

-- ## Version in the TOC.
local tocOut, tocCount = toc:gsub("(##%s*Version:%s*)" .. version:gsub("%.", "%%."), "%1" .. newVersion, 1)
assert(tocCount == 1, "failed to rewrite ## Version")
write(TOC, tocOut)

-- The banner at the top of the Lua file.
local lua = read(LUA)
local luaOut, luaCount = lua:gsub("v" .. version:gsub("%.", "%%."), "v" .. newVersion, 1)
assert(luaCount == 1, "failed to rewrite the version banner in LootToastMover.lua")
write(LUA, luaOut)

-- A changelog entry, inserted above the most recent existing one.
local changelog = read(CHANGELOG)
local note = reason
if not note or note == "" then
    local game = gameVersion(interface)
    note = game and ("Updated for patch " .. game .. " (Interface `" .. interface .. "`).")
        or ("Updated for Interface `" .. interface .. "`.")
end

local entry = ("## [%s] - %s\n\n### Changed\n\n- %s\n\n"):format(
    newVersion, os.date("!%Y-%m-%d"), note)

local updated, count = changelog:gsub("\n(## %[)", "\n" .. entry:gsub("%%", "%%%%") .. "%1", 1)
assert(count == 1, "could not find an existing changelog entry to insert above")
write(CHANGELOG, updated)

print(newVersion)
