-- Regression tests for LootToastMover, run outside the game against a stubbed WoW API.
--
--   lua5.1 tests/run_tests.lua
--
-- Each section guards a bug that shipped in 4.8.3. See tests/README.md.

local here = (arg and arg[0] or "tests/run_tests.lua"):match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. package.path
local stub = require("wow_stub")
local print = stub.stdout -- the stub replaces the global print to capture addon chat

-- Override to run the suite against a different copy of the addon, e.g. to confirm these
-- tests really do fail against an older revision.
local ADDON_DIR = os.getenv("LTM_ADDON_DIR") or (here .. "/../LootToastMover")

local passed, failed = 0, 0

local function check(cond, what)
    if cond then
        passed = passed + 1
        print("    ok    " .. what)
    else
        failed = failed + 1
        print("    FAIL  " .. what)
    end
    return cond and true or false
end

--- Run one section. A section that raises is reported as a failure rather than killing
--- the run, so a revision that cannot even load still produces a full report.
local function test(name, fn)
    print("\n" .. name)
    local ok, err = pcall(fn)
    if not ok then
        failed = failed + 1
        print("    FAIL  section raised an error")
        print("          " .. tostring(err))
    end
end

--- The addon's files, in the order the TOC lists them. Load order is part of what these
--- tests cover, so it is read from the TOC rather than hardcoded here.
local function tocFiles()
    local files = {}
    local fh = assert(io.open(ADDON_DIR .. "/LootToastMover.toc"), "cannot open LootToastMover.toc")
    for line in fh:lines() do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            table.insert(files, (line:gsub("\\", "/")))
        end
    end
    fh:close()
    return files
end

--- Load the addon the way the client would: every file, in TOC order.
-- @param opts.withLibs load the vendored libraries (default true; false simulates the
--        Libs folder not being installed)
-- @param opts.savedVars a table to install as LootToastMoverDB before loading
-- @return the anchor frame, or nil plus the error that stopped the load
local function loadAddon(opts)
    opts = opts or {}
    stub.reset()
    if opts.savedVars then _G.LootToastMoverDB = opts.savedVars end

    for _, rel in ipairs(tocFiles()) do
        if rel:find("^Libs/") and opts.withLibs == false then
            -- skip: simulating the libraries not being installed
        elseif rel:find("LibDBIcon") then
            -- The real LibDBIcon needs far more of the widget API than this stub models,
            -- so substitute the stand-in that reproduces its registration contract.
            if _G.LibStub then stub.installDBIcon() end
        else
            local chunk, loadErr = loadfile(ADDON_DIR .. "/" .. rel)
            if not chunk then return nil, loadErr end
            -- WoW passes the addon's name as each file's vararg.
            local ok, err = pcall(chunk, "LootToastMover")
            if not ok then return nil, err end
        end
    end

    FireEvent("ADDON_LOADED", "LootToastMover")
    _G._loggedIn = true
    FireEvent("PLAYER_LOGIN")
    TickAll(3)
    _G.CHAT = {}
    return _G.LootToastMoverAnchor
end

--- loadAddon, raising a readable error when the addon does not load.
local function mustLoad(opts)
    local anchor, err = loadAddon(opts)
    if not anchor then error("addon failed to load: " .. tostring(err), 0) end
    return anchor
end

------------------------------------------------------------------------------------------
-- Regression: the addon's own file was listed before the libraries in the TOC, so LibStub
-- was still nil when the addon called it, and the addon failed to load outright unless
-- some other addon happened to pull LibStub in first.
test("Loads cleanly when LootToastMover is the only addon installed", function()
    local anchor, err = loadAddon()
    if check(anchor ~= nil, "addon loads without another addon providing LibStub") then
        check(anchor:GetPoint() ~= nil, "anchor is positioned at login")
        check(AlertFrame:GetPoint() ~= nil, "AlertFrame is anchored to the anchor box")
    else
        print("          " .. tostring(err))
    end
end)

------------------------------------------------------------------------------------------
-- Regression: the handler called the removed IsAddOnLoaded global, and re-registered the
-- minimap icon on every invocation, which LibDBIcon treats as a fatal error.
test("Slash command survives repeated use", function()
    local anchor = mustLoad()
    local slash = SlashCmdList.LOOTTOASTPOS
    local before = anchor:IsShown()
    local ok1, e1 = pcall(slash, "")
    local ok2, e2 = pcall(slash, "")
    local ok3 = pcall(slash, "")
    check(ok1, "1st /loottoastpos does not error" .. (ok1 and "" or ": " .. tostring(e1)))
    check(ok2, "2nd /loottoastpos does not error" .. (ok2 and "" or ": " .. tostring(e2)))
    check(ok3, "3rd /loottoastpos does not error")
    check(anchor:IsShown() ~= before, "an odd number of toggles flipped visibility")
end)

------------------------------------------------------------------------------------------
-- Regression: Register() was handed a fresh {} each time, so LibDBIcon wrote the dragged
-- position into a table that was thrown away at logout.
test("Minimap button state is persisted", function()
    mustLoad()
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if check(DBIcon and DBIcon:GetMinimapButton("LootToastMover") ~= nil,
             "minimap button is registered") then
        DBIcon:SimulateDrag("LootToastMover", 137.5)
        check(LootToastMoverDB.minimap and LootToastMoverDB.minimap.minimapPos == 137.5,
              "dragged position is stored in LootToastMoverDB.minimap")
    end
end)

------------------------------------------------------------------------------------------
test("Anchor position round-trips through SavedVariables", function()
    local anchor = mustLoad()
    anchor:SetPoint("CENTER", UIParent, "CENTER", 123, -45)
    local onDragStop = anchor:GetScript("OnDragStop")
    check(onDragStop ~= nil, "OnDragStop handler is installed")
    onDragStop(anchor)
    check(LootToastMoverDB.point == "CENTER" and LootToastMoverDB.xOfs == 123
              and LootToastMoverDB.yOfs == -45, "dropped position is saved")

    -- Log back in with those saved variables and confirm the anchor returns to place.
    local anchor2 = mustLoad({ savedVars = LootToastMoverDB })
    local p, _, rp, x, y = anchor2:GetPoint()
    check(p == "CENTER" and rp == "CENTER" and x == 123 and y == -45,
          "saved position is restored on the next login")
end)

------------------------------------------------------------------------------------------
-- Regression: OnDragStop replaced the whole LootToastMoverDB table, and reset wiped it.
-- Either one discarded LibDBIcon's sub-table along with it.
test("Minimap settings survive anchor changes", function()
    local anchor = mustLoad()
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    DBIcon:SimulateDrag("LootToastMover", 137.5)

    anchor:SetPoint("CENTER", UIParent, "CENTER", 10, 20)
    anchor:GetScript("OnDragStop")(anchor)
    check(LootToastMoverDB.minimap and LootToastMoverDB.minimap.minimapPos == 137.5,
          "dragging the anchor preserves LootToastMoverDB.minimap")

    SlashCmdList.LOOTTOASTPOS("reset")
    check(LootToastMoverDB.point == nil, "reset clears the saved anchor position")
    check(LootToastMoverDB.minimap and LootToastMoverDB.minimap.minimapPos == 137.5,
          "reset preserves LootToastMoverDB.minimap")
end)

------------------------------------------------------------------------------------------
-- Regression: the argument was compared without trimming, so a stray space silently
-- toggled the anchor instead of resetting, and unknown input gave no feedback at all.
test("Slash argument parsing", function()
    local anchor = mustLoad()
    anchor:SetPoint("CENTER", UIParent, "CENTER", 1, 2)
    anchor:GetScript("OnDragStop")(anchor)

    SlashCmdList.LOOTTOASTPOS("  RESET  ")
    check(LootToastMoverDB.point == nil, "'  RESET  ' is recognised despite padding and case")

    _G.CHAT = {}
    local shown = anchor:IsShown()
    SlashCmdList.LOOTTOASTPOS("bogus")
    check(#_G.CHAT > 0, "unknown argument prints usage")
    check(anchor:IsShown() == shown, "unknown argument does not toggle the anchor")
end)

------------------------------------------------------------------------------------------
-- Regression: a 1-second ticker retried broker creation forever, for the whole session.
test("No leaked timers", function()
    mustLoad()
    TickAll(10)
    check(UnboundedTickers() == 0, "no unbounded tickers are left running")
end)

------------------------------------------------------------------------------------------
test("Degrades gracefully when the libraries are absent", function()
    local anchor, err = loadAddon({ withLibs = false })
    if check(anchor ~= nil, "addon loads with no LibStub present") then
        check(anchor:GetPoint() ~= nil, "anchor is still positioned")
        check(AlertFrame:GetPoint() ~= nil, "AlertFrame is still anchored")
        check(pcall(SlashCmdList.LOOTTOASTPOS, ""), "/loottoastpos still works")
        check(pcall(SlashCmdList.LOOTTOASTPOS, "reset"), "/loottoastpos reset still works")
    else
        print("          " .. tostring(err))
    end
end)

------------------------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
