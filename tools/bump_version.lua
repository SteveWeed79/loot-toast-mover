-- Bumps the addon's version and records it in the changelog.
--
--   lua5.1 tools/bump_version.lua <none|patch|minor|major> [changelog note]
--
-- Prints the resulting version to stdout, which is what the release workflow tags.
--
--   none    leave the version alone and report it, for releasing what is already committed
--   patch   4.10.0 -> 4.10.1
--   minor   4.10.0 -> 4.11.0
--   major   4.10.0 -> 5.0.0
--
-- With no note, the entry names every game's version from the TOC's Interface line, which
-- is what a release that only updates the Interface versions wants. Pass one explicitly for
-- anything else.
--
-- Three things have to move together or tests/check_toc.lua fails the build:
--   * ## Version in LootToastMover.toc
--   * the vX.Y.Z banner at the top of LootToastMover.lua
--   * a CHANGELOG.md entry for the new version

local here = (arg and arg[0] or "tools/bump_version.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = os.getenv("LTM_ADDON_DIR") or (here .. "/..")

package.path = here .. "/?.lua;" .. package.path
local games = require("games")

local TOC = ROOT .. "/LootToastMover.toc"
local LUA = ROOT .. "/LootToastMover.lua"
local CHANGELOG = ROOT .. "/CHANGELOG.md"

local kind = (arg and arg[1] or ""):lower()
local note = arg and arg[2]

local VALID = { none = true, patch = true, minor = true, major = true }
if not VALID[kind] then
    io.stderr:write("usage: bump_version.lua <none|patch|minor|major> [changelog note]\n")
    os.exit(2)
end

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

--- "A", "A and B", "A, B and C".
local function joinList(items)
    if #items < 2 then return items[1] or "" end
    return table.concat(items, ", ", 1, #items - 1) .. " and " .. items[#items]
end

local toc = read(TOC)

local version = toc:match("##%s*Version:%s*([%d%.]+)")
assert(version, "no ## Version in the TOC")
local interfaces = toc:match("##%s*Interface:([^\r\n]*)")
assert(interfaces and interfaces:find("%d"), "no ## Interface in the TOC")

-- Releasing what is already committed: report the version and change nothing.
if kind == "none" then
    print(version)
    return
end

local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
assert(major, "## Version is not a three-part version: " .. version)
major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)

local newVersion
if kind == "major" then
    newVersion = ("%d.0.0"):format(major + 1)
elseif kind == "minor" then
    newVersion = ("%d.%d.0"):format(major, minor + 1)
else
    newVersion = ("%d.%d.%d"):format(major, minor, patch + 1)
end

local escaped = version:gsub("%.", "%%.")

-- ## Version in the TOC.
local tocOut, tocCount = toc:gsub("(##%s*Version:%s*)" .. escaped, "%1" .. newVersion, 1)
assert(tocCount == 1, "failed to rewrite ## Version")
write(TOC, tocOut)

-- The banner at the top of the Lua file.
local lua = read(LUA)
local luaOut, luaCount = lua:gsub("v" .. escaped, "v" .. newVersion, 1)
assert(luaCount == 1, "failed to rewrite the version banner in LootToastMover.lua")
write(LUA, luaOut)

-- A changelog entry, inserted above the most recent existing one.
if not note or note == "" then
    -- "Retail 12.1.0", "Classic Era 1.15.9", ... in the TOC's own order. A number for no
    -- known game is listed as it is; tests/check_toc.lua stops that release anyway.
    local updated = {}
    for interface in interfaces:gmatch("%d+") do
        local game, gameVersion = games.of(interface), games.version(interface)
        table.insert(updated, (game and gameVersion) and (game.name .. " " .. gameVersion)
            or ("Interface `" .. interface .. "`"))
    end
    note = "Updated for the current version of every game: " .. joinList(updated) .. "."
end

local entry = ("## [%s] - %s\n\n### Changed\n\n- %s\n\n"):format(
    newVersion, os.date("!%Y-%m-%d"), note)

local changelog = read(CHANGELOG)
local updated, count = changelog:gsub("\n(## %[)", "\n" .. entry:gsub("%%", "%%%%") .. "%1", 1)
assert(count == 1, "could not find an existing changelog entry to insert above")
write(CHANGELOG, updated)

print(newVersion)
