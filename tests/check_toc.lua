-- Sanity-checks LootToastMover.toc.
--
--   lua5.1 tests/check_toc.lua
--
-- A malformed TOC is invisible until the client silently refuses to load the addon, so the
-- things that cause that are worth asserting in CI.

local here = (arg and arg[0] or "tests/check_toc.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = os.getenv("LTM_ADDON_DIR") or (here .. "/..")
local TOC = ROOT .. "/LootToastMover.toc"

-- Which games the addon ships for, and how to tell their Interface numbers apart. Loaded
-- from this checkout even when LTM_ADDON_DIR points at another one, so an older revision
-- is judged against what the addon is meant to support now.
package.path = here .. "/../tools/?.lua;" .. package.path
local games = require("games")

local problems = {}
local function fail(msg) table.insert(problems, msg) end

local fh = assert(io.open(TOC), "cannot open " .. TOC)
local directives, files = {}, {}
for line in fh:lines() do
    line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local key, value = line:match("^##%s*([%w%-_]+)%s*:%s*(.*)$")
    if key then
        directives[key] = value
    elseif line ~= "" and line:sub(1, 1) ~= "#" then
        table.insert(files, (line:gsub("\\", "/")))
    end
end
fh:close()

-- Required metadata.
for _, key in ipairs({ "Interface", "Title", "Version", "SavedVariables" }) do
    if not directives[key] or directives[key] == "" then
        fail("missing ## " .. key)
    end
end

-- One TOC serves every game by listing an Interface number for each. Every number has to
-- belong to one of them, each has to clear its game's floor, and no game may go missing.
-- The release workflow's Interface update rewrites this whole line from Blizzard's version
-- servers, so a lookup that fails or returns some other game's build has to stop the
-- release here rather than ship.
local interfaces, listed = {}, {}
if directives.Interface and directives.Interface ~= "" then
    for entry in (directives.Interface .. ","):gmatch("([^,]*),") do
        local interface = tonumber(entry:match("^%s*(%d+)%s*$"))
        local game = interface and games.of(interface)
        if not interface then
            fail(("## Interface lists '%s', which is not a number"):format(entry))
        elseif not game then
            fail(("## Interface %d is not a number for any game the addon is built for; "
                .. "add the game to tools/games.lua once the addon has been checked "
                .. "against it"):format(interface))
        elseif game.floor and interface < game.floor then
            fail(("## Interface %d is below the %d floor for %s; the client will not load "
                .. "the addon for a normal user"):format(interface, game.floor, game.name))
        end
        if interface then table.insert(interfaces, interface) end
        if game then listed[game] = true end
    end
    for _, game in ipairs(games.list) do
        if not listed[game] then fail("## Interface has no " .. game.name .. " number") end
    end
end

-- The in-file version banner should track ## Version, since they drifted apart before.
local lua = assert(io.open(ROOT .. "/LootToastMover.lua"), "cannot open LootToastMover.lua")
local source = lua:read("*a")
lua:close()
local banner = source:match("LootToastMover%s*[^%w]*%s*v([%d%.]+)")
if directives.Version and banner and banner ~= directives.Version then
    fail(("version banner in LootToastMover.lua is v%s but ## Version is %s")
        :format(banner, directives.Version))
end

-- CurseForge uploads are matched by project id, so a typo here publishes nowhere.
if not (directives["X-Curse-Project-ID"] or ""):match("^%d+$") then
    fail("## X-Curse-Project-ID is missing or not numeric")
end

-- The Addon Compartment looks its handlers up as globals by the name given in the TOC, so
-- a rename that misses one side silently produces a dead compartment entry.
for _, key in ipairs({ "AddonCompartmentFunc", "AddonCompartmentFuncOnEnter",
                       "AddonCompartmentFuncOnLeave" }) do
    local fname = directives[key]
    if not fname or fname == "" then
        fail("missing ## " .. key)
    elseif not source:find("function%s+" .. fname:gsub("%W", "%%%0") .. "%s*%(") then
        fail(("## %s names %s, but LootToastMover.lua defines no such global function")
            :format(key, fname))
    end
end

-- Every listed file has to exist, and load order has to put dependencies first.
local seenLib, addonIndex = false, nil
for i, rel in ipairs(files) do
    local f = io.open(ROOT .. "/" .. rel)
    if f then f:close() else fail("listed file does not exist: " .. rel) end
    if rel:find("^Libs/") then seenLib = true end
    if rel == "LootToastMover.lua" then addonIndex = i end
end
if #files == 0 then fail("the TOC lists no files") end
if not addonIndex then
    fail("LootToastMover.lua is not listed in the TOC")
elseif seenLib and files[addonIndex + 1] and files[addonIndex + 1]:find("^Libs/") then
    fail("LootToastMover.lua is listed before a library; LibStub would still be nil")
end

-- The packager falls back to a changelog generated from raw commit messages when the
-- manual-changelog file cannot be found, and says nothing about it. Check the file named
-- in .pkgmeta really is there, and that it actually mentions the version being shipped.
local pkgmeta = io.open(ROOT .. "/.pkgmeta")
if not pkgmeta then
    fail(".pkgmeta is missing")
else
    local meta = pkgmeta:read("*a")
    pkgmeta:close()
    -- Only the filename is needed, from either the plain or the extended form.
    local changelog = meta:match("manual%-changelog:%s*\n%s*filename:%s*([^%s\n]+)")
        or meta:match("manual%-changelog:%s*([^%s\n]+)")
    if not changelog then
        fail(".pkgmeta has no manual-changelog, so CurseForge gets raw commit messages")
    else
        local changelogFile = io.open(ROOT .. "/" .. changelog)
        if not changelogFile then
            fail(("`.pkgmeta` names %s as the changelog but it does not exist; the "
                .. "packager would silently publish commit messages instead"):format(changelog))
        else
            local text = changelogFile:read("*a")
            changelogFile:close()
            local version = directives.Version or ""
            if version ~= "" and not text:find(version, 1, true) then
                fail(("%s has no entry for version %s"):format(changelog, version))
            end
        end
    end
end

if #problems > 0 then
    print(("%d problem(s) found:"):format(#problems))
    for _, p in ipairs(problems) do print("  - " .. p) end
    os.exit(1)
end

print(("LootToastMover.toc ok (Interface %s, version %s, %d files, changelog present)")
    :format(table.concat(interfaces, ", "), directives.Version, #files))
