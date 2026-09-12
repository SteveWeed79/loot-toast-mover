-- Regression tests for LootToastMover, run outside the game against a stubbed WoW API.
--
--   lua5.1 tests/run_tests.lua
--
-- Most sections guard a bug that shipped in 4.8.3. See tests/README.md.

local here = (arg and arg[0] or "tests/run_tests.lua"):match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. package.path
local stub = require("wow_stub")
local print = stub.stdout -- the stub replaces the global print to capture addon chat

-- Override to run the suite against a different copy of the addon, e.g. to confirm these
-- tests really do fail against an older revision.
local ADDON_DIR = os.getenv("LTM_ADDON_DIR") or (here .. "/..")

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

--- Load the addon the way the client would: every file the TOC lists, in order.
-- @param opts.savedVars a table to install as LootToastMoverDB before loading
-- @return the anchor frame, or nil plus the error that stopped the load
local function loadAddon(opts)
    opts = opts or {}
    stub.reset()
    if opts.savedVars then _G.LootToastMoverDB = opts.savedVars end

    for _, rel in ipairs(tocFiles()) do
        local chunk, loadErr = loadfile(ADDON_DIR .. "/" .. rel)
        if not chunk then return nil, loadErr end
        -- WoW passes the addon's name as each file's vararg.
        local ok, err = pcall(chunk, "LootToastMover")
        if not ok then return nil, err end
    end

    FireEvent("ADDON_LOADED", "LootToastMover")
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
-- was still nil when the addon called it. The libraries are gone now, but the addon must
-- still stand alone with no third-party code present at all.
test("Loads standalone with no third-party libraries", function()
    local anchor, err = loadAddon()
    if check(anchor ~= nil, "addon loads with nothing but its own file") then
        check(anchor:GetPoint() ~= nil, "anchor is positioned at login")
        check(AlertFrame:GetPoint() ~= nil, "AlertFrame is anchored to the anchor box")
        check(_G.LibStub == nil, "no LibStub is required or defined")
    else
        print("          " .. tostring(err))
    end
end)

------------------------------------------------------------------------------------------
-- Regression: the handler called the removed IsAddOnLoaded global, and re-registered a
-- minimap icon on every invocation, which LibDBIcon treated as a fatal error.
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
-- The Addon Compartment calls these by name, looked up as globals from the TOC fields, so
-- a rename that misses the TOC silently produces a dead compartment entry.
test("Addon Compartment entry points", function()
    local anchor = mustLoad()
    check(type(_G.LootToastMover_OnCompartmentClick) == "function", "click handler is a global function")
    check(type(_G.LootToastMover_OnCompartmentEnter) == "function", "enter handler is a global function")
    check(type(_G.LootToastMover_OnCompartmentLeave) == "function", "leave handler is a global function")

    -- Blizzard calls these as func(addonName, buttonName) and func(addonName, button).
    local before = anchor:IsShown()
    LootToastMover_OnCompartmentClick("LootToastMover", "LeftButton")
    check(anchor:IsShown() ~= before, "clicking the compartment entry toggles the anchor")
    LootToastMover_OnCompartmentClick("LootToastMover", "LeftButton")
    check(anchor:IsShown() == before, "clicking again toggles it back")

    local button = { _name = "CompartmentButton" }
    LootToastMover_OnCompartmentEnter("LootToastMover", button)
    check(GameTooltip.owner == button, "tooltip is owned by the compartment button")
    check(#GameTooltip.lines >= 2, "tooltip has content")
    check(GameTooltip.lines[1] == "LootToastMover", "tooltip is titled")
    check(GameTooltip:IsShown(), "tooltip is shown on enter")

    LootToastMover_OnCompartmentLeave("LootToastMover", button)
    check(not GameTooltip:IsShown(), "tooltip is hidden on leave")
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
test("Reset clears only the anchor position", function()
    local anchor = mustLoad()
    anchor:SetPoint("CENTER", UIParent, "CENTER", 10, 20)
    anchor:GetScript("OnDragStop")(anchor)
    check(LootToastMoverDB.point == "CENTER", "position saved before reset")

    SlashCmdList.LOOTTOASTPOS("reset")
    check(LootToastMoverDB.point == nil, "reset clears the saved anchor position")
    check(type(LootToastMoverDB) == "table", "reset leaves the saved variables table intact")
    check(anchor:GetPoint() == "TOP", "reset moves the anchor back to its default point")
end)

------------------------------------------------------------------------------------------
-- The LibDBIcon minimap button is gone, so its saved sub-table is dead weight. Upgrading
-- from 4.8.x must clear it rather than leave it in the saved variables file forever.
test("Upgrading from 4.8.x drops the stale minimap table", function()
    mustLoad({ savedVars = { point = "TOP", relPoint = "TOP", xOfs = 0, yOfs = -200,
                             minimap = { minimapPos = 137.5 } } })
    check(LootToastMoverDB.minimap == nil, "leftover minimap sub-table is removed on load")
    check(LootToastMoverDB.point == "TOP", "the anchor position is not disturbed by the cleanup")
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
-- Blizzard calls AlertFrame:UpdateAnchors() whenever an alert appears; the hook has to put
-- the alerts back on our anchor every time, not just once at login.
test("Alerts stay on the anchor after Blizzard re-anchors", function()
    local anchor = mustLoad()
    AlertFrame:ClearAllPoints()
    check(AlertFrame:GetPoint() == nil, "AlertFrame starts unanchored for this check")
    AlertFrame:UpdateAnchors()
    local _, rel = AlertFrame:GetPoint()
    check(rel == anchor, "AlertFrame is re-anchored to the anchor box")
end)

------------------------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
