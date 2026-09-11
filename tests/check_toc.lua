-- Sanity-checks LootToastMover.toc.
--
--   lua5.1 tests/check_toc.lua
--
-- A malformed TOC is invisible until the client silently refuses to load the addon, so the
-- things that cause that are worth asserting in CI.

local here = (arg and arg[0] or "tests/check_toc.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = os.getenv("LTM_ADDON_DIR") or (here .. "/..")
local TOC = ROOT .. "/LootToastMover.toc"

-- Addons below this are refused outright by a 12.x client.
local MIN_INTERFACE = 120000

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

-- Interface number must be current enough for the client to load the addon at all.
local interface = tonumber((directives.Interface or ""):match("^%s*(%d+)"))
if not interface then
    fail("## Interface is not a number: " .. tostring(directives.Interface))
elseif interface < MIN_INTERFACE then
    fail(("## Interface %d is below %d; a 12.x client will not load the addon")
        :format(interface, MIN_INTERFACE))
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

-- Every listed file has to exist, and the libraries have to come before the file that
-- uses them.
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

if #problems > 0 then
    print(("%d problem(s) in LootToastMover.toc:"):format(#problems))
    for _, p in ipairs(problems) do print("  - " .. p) end
    os.exit(1)
end

print(("LootToastMover.toc ok (Interface %d, version %s, %d files)")
    :format(interface, directives.Version, #files))
