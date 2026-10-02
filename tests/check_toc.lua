-- Sanity-checks LootToastMover.toc.
--
--   lua5.1 tests/check_toc.lua
--
-- A malformed TOC is invisible until the client silently refuses to load the addon, so the
-- things that cause that are worth asserting in CI.

local here = (arg and arg[0] or "tests/check_toc.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = os.getenv("LTM_ADDON_DIR") or (here .. "/..")
local TOC = ROOT .. "/LootToastMover.toc"

-- Patch 12.0 raised the floor for mainline addons to 120000. Sources disagree on whether
-- a lower number is merely flagged out of date or refused outright, but either way an
-- addon below this does not load for a normal user.
local MIN_INTERFACE = 120000

--- Which of the addon's two games an Interface number is for, or nil for any other client.
--- Retail numbers have had six digits since 10.0. Forever's are 16xxx, which is also how
--- the BigWigs packager tells them apart when it tags the CurseForge upload. There is no
--- Forever floor to check: every Forever build so far is 1.60.1, Interface 16001.
local function gameOf(interface)
    if interface >= 100000 and interface <= 999999 then return "retail" end
    if interface >= 16000 and interface <= 16999 then return "Forever" end
end

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

-- One TOC serves both games by listing an Interface number for each. Every number has to
-- belong to one of them, retail's has to clear the floor, and neither game may go missing.
-- The release workflow's Interface update rewrites this whole line from Blizzard's version
-- servers, so a lookup that fails or returns some other game's build has to stop the
-- release here rather than ship.
local interfaces, listed = {}, {}
if directives.Interface and directives.Interface ~= "" then
    for entry in (directives.Interface .. ","):gmatch("([^,]*),") do
        local interface = tonumber(entry:match("^%s*(%d+)%s*$"))
        local game = interface and gameOf(interface)
        if not interface then
            fail(("## Interface lists '%s', which is not a number"):format(entry))
        elseif not game then
            fail(("## Interface %d is not a retail or Forever number, and the addon is "
                .. "built for those two only"):format(interface))
        elseif game == "retail" and interface < MIN_INTERFACE then
            fail(("## Interface %d is below the %d floor for patch 12.x; the client will "
                .. "not load the addon for a normal user"):format(interface, MIN_INTERFACE))
        end
        if interface then table.insert(interfaces, interface) end
        if game then listed[game] = true end
    end
    for _, game in ipairs({ "retail", "Forever" }) do
        if not listed[game] then fail("## Interface has no " .. game .. " number") end
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
