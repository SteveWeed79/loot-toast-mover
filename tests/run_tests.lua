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
-- @param opts.broker install LibStub + LibDataBroker first, as a broker display would
-- @return the anchor frame, or nil plus the error that stopped the load
local function loadAddon(opts)
    opts = opts or {}
    stub.reset()
    if opts.savedVars then _G.LootToastMoverDB = opts.savedVars end
    if opts.broker then InstallBrokerLibs() end

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
-- The box is meant to be the toast's real footprint, so that dragging it shows exactly
-- where toasts land. Alerts anchor BOTTOM-to-BOTTOM with AlertFrame and stack upward, so
-- AlertFrame's bottom edge has to sit on the box's bottom edge with no fudge offset.
test("Anchor box is the toast footprint", function()
    local anchor = mustLoad()
    check(anchor:GetWidth() == 276 and anchor:GetHeight() == 96,
          "anchor box matches LootWonAlertFrameTemplate's 276x96")

    local point, rel, relPoint, x, y = AlertFrame:GetPoint()
    check(point == "BOTTOM" and relPoint == "BOTTOM", "AlertFrame is pinned bottom-to-bottom")
    check(rel == anchor, "AlertFrame is pinned to the anchor box")
    check(x == 0 and y == 0, "no magic offset between the box and the toast")
end)

------------------------------------------------------------------------------------------
-- /loottoastpos test fires a real toast through Blizzard's alert system. GetItemInfo
-- returns nil for an uncached item and LootWonAlertFrame_SetUp passes that nil into its
-- Azerite and Conduit checks, so the alert must wait for the item data to load.
test("Sample toast", function()
    mustLoad()
    SlashCmdList.LOOTTOASTPOS("test")
    check(#LootAlertSystem.alerts == 0, "nothing is fired before the item data resolves")
    check(#_G.PENDING_ITEM_LOADS == 1, "the item load is pending")

    FlushItemLoads()
    check(#LootAlertSystem.alerts == 1, "one toast is fired once the item loads")
    local alert = LootAlertSystem.alerts[1]
    check(type(alert.link) == "string" and alert.link:find("Hitem:", 1, true) ~= nil,
          "the toast is given a real item link, not nil")
    check(alert.quantity == 1, "quantity is 1")

    -- The sample toast must not disturb the saved position.
    check(LootToastMoverDB.point == nil, "firing a sample toast does not write a position")
end)

------------------------------------------------------------------------------------------
-- 4.9.x put the first toast's bottom edge 31px below a 60px-tall box. The box is now 96px
-- tall with the toast sitting directly on it, so saved positions must shift or everyone's
-- toasts silently move on upgrade. The shift depends on the anchor point, because resizing
-- the box moves its bottom edge by a different amount for each one.
test("Upgrading from 4.9.x keeps toasts where they were", function()
    -- delta = fraction * (96 - 60) - 31, where fraction is how far the bottom edge sits
    -- below the anchor point: TOP = 1, CENTER = 0.5, BOTTOM = 0.
    local cases = {
        { point = "TOP",         yOfs = -200, expected = -200 + 5 },
        { point = "TOPLEFT",     yOfs = -200, expected = -200 + 5 },
        { point = "CENTER",      yOfs = 0,    expected = 0 - 13 },
        { point = "LEFT",        yOfs = 40,   expected = 40 - 13 },
        { point = "BOTTOM",      yOfs = 100,  expected = 100 - 31 },
        { point = "BOTTOMRIGHT", yOfs = 100,  expected = 100 - 31 },
    }
    for _, case in ipairs(cases) do
        mustLoad({ savedVars = { point = case.point, relPoint = case.point, xOfs = 0,
                                 yOfs = case.yOfs } })
        check(LootToastMoverDB.yOfs == case.expected,
              ("%s: yOfs %d -> %d (got %s)"):format(case.point, case.yOfs, case.expected,
                                                    tostring(LootToastMoverDB.yOfs)))
    end
end)

-- The check above pins the exact numbers. This one proves the intent instead, deriving the
-- answer from the two layouts rather than from the addon's own formula: the first toast's
-- bottom edge must end up at the same screen position it occupied before the upgrade.
test("The upgrade shift is geometrically correct", function()
    local LEGACY_HEIGHT, LEGACY_GAP, NEW_HEIGHT = 60, 31, 96
    local fractions = { TOP = 1, TOPLEFT = 1, CENTER = 0.5, LEFT = 0.5,
                        BOTTOM = 0, BOTTOMRIGHT = 0 }
    for point, fraction in pairs(fractions) do
        local originalY = -137 -- arbitrary; the reference point cancels out
        -- Where 4.9.x actually drew the toast, relative to the stored anchor point.
        local before = originalY - fraction * LEGACY_HEIGHT - LEGACY_GAP
        mustLoad({ savedVars = { point = point, relPoint = point, xOfs = 0, yOfs = originalY } })
        -- Where this version draws it, from the migrated offset.
        local after = LootToastMoverDB.yOfs - fraction * NEW_HEIGHT
        check(math.abs(after - before) < 0.001,
              ("%s: toast bottom stays at %.1f (got %.1f)"):format(point, before, after))
    end
end)

test("The upgrade shift runs exactly once", function()
    local saved = { point = "TOP", relPoint = "TOP", xOfs = 0, yOfs = -200 }
    mustLoad({ savedVars = saved })
    local afterFirst = LootToastMoverDB.yOfs
    check(afterFirst == -195, "shifted on first load")

    -- Log in again with the already-migrated table; it must not shift a second time.
    mustLoad({ savedVars = LootToastMoverDB })
    check(LootToastMoverDB.yOfs == afterFirst, "not shifted again on the next login")

    -- A fresh install has no position to migrate and must not invent one.
    mustLoad()
    check(LootToastMoverDB.point == nil, "a fresh install still has no saved position")
    check(LootToastMoverDB.yOfs == nil, "and no invented offset")
end)

------------------------------------------------------------------------------------------
-- 4.9.0 traded the minimap button for the Addon Compartment alone, which left players who
-- do not use the compartment with no visible sign the addon was installed at all. The
-- button is back, written against the widget API so nothing is bundled for it.
test("Minimap button", function()
    local anchor = mustLoad()
    local button = _G.LootToastMoverMinimapButton
    if not check(button ~= nil, "a minimap button frame exists") then return end
    check(button:IsShown(), "it is shown by default")
    check(button:GetPoint() ~= nil, "it is positioned on the minimap")

    local onClick = button:GetScript("OnClick")
    if check(onClick ~= nil, "OnClick handler is installed") then
        local before = anchor:IsShown()
        onClick(button, "LeftButton")
        check(anchor:IsShown() ~= before, "left-click toggles the anchor box")
        onClick(button, "LeftButton")
        check(anchor:IsShown() == before, "left-click again toggles it back")

        local shown = anchor:IsShown()
        onClick(button, "RightButton")
        check(#Settings.opened == 1, "right-click opens the options panel")
        check(anchor:IsShown() == shown, "right-click does not toggle the anchor box")
    end

    local onEnter = button:GetScript("OnEnter")
    if check(onEnter ~= nil, "OnEnter handler is installed") then
        onEnter(button)
        check(GameTooltip.owner == button, "tooltip is owned by the minimap button")
        check(GameTooltip.lines[1] == "LootToastMover", "tooltip is titled")
        button:GetScript("OnLeave")(button)
        check(not GameTooltip:IsShown(), "tooltip is hidden on leave")
    end
end)

------------------------------------------------------------------------------------------
-- Dragging the button has to survive a logout, and must not resurrect the LibDBIcon table
-- that the 4.8.x cleanup exists to remove.
test("Minimap button position round-trips", function()
    mustLoad()
    local button = _G.LootToastMoverMinimapButton
    local defaultAngle = LootToastMoverDB.minimapButton.angle
    check(type(defaultAngle) == "number", "a default angle is stored")

    -- Drag the button to due north of the minimap's centre, which is 90 degrees.
    button:GetScript("OnDragStart")(button)
    local onUpdate = button:GetScript("OnUpdate")
    if check(onUpdate ~= nil, "dragging installs an OnUpdate follower") then
        local cx, cy = Minimap:GetCenter()
        MoveCursorTo(cx, cy + 100)
        onUpdate(button)
        check(math.abs(LootToastMoverDB.minimapButton.angle - 90) < 0.001,
              ("drag stores the cursor's angle (got %s)")
                  :format(tostring(LootToastMoverDB.minimapButton.angle)))
    end
    button:GetScript("OnDragStop")(button)
    check(button:GetScript("OnUpdate") == nil, "releasing stops following the cursor")

    mustLoad({ savedVars = LootToastMoverDB })
    check(math.abs(LootToastMoverDB.minimapButton.angle - 90) < 0.001,
          "the dragged angle survives the next login")
    check(LootToastMoverDB.minimap == nil, "the stale LibDBIcon table is still not recreated")
end)

------------------------------------------------------------------------------------------
test("Minimap button can be hidden and stays hidden", function()
    mustLoad()
    local button = _G.LootToastMoverMinimapButton
    check(button:IsShown(), "shown to begin with")

    SlashCmdList.LOOTTOASTPOS("minimap")
    check(not button:IsShown(), "/ltm minimap hides it")
    check(LootToastMoverDB.minimapButton.hide == true, "the choice is saved")

    mustLoad({ savedVars = LootToastMoverDB })
    check(not _G.LootToastMoverMinimapButton:IsShown(), "still hidden after logging back in")

    SlashCmdList.LOOTTOASTPOS("minimap")
    check(_G.LootToastMoverMinimapButton:IsShown(), "/ltm minimap brings it back")
    check(LootToastMoverDB.minimapButton.hide == false, "and saves that too")
end)

------------------------------------------------------------------------------------------
-- Nothing appeared under Options → AddOns before, so players looking there concluded the
-- addon had not loaded.
test("Options panel is registered with the game's settings", function()
    mustLoad()
    check(#Settings.categories == 1, "exactly one AddOns category is registered")
    local category = Settings.categories[1]
    if check(category ~= nil, "the category exists") then
        check(category.name == "LootToastMover", "it is named after the addon")
        check(category.frame == _G.LootToastMoverOptionsPanel, "it owns the panel frame")
    end

    SlashCmdList.LOOTTOASTPOS("config")
    check(#Settings.opened == 1, "/ltm config opens the settings panel")
    check(Settings.opened[1] == category:GetID(), "it opens this addon's category")
end)

------------------------------------------------------------------------------------------
-- Blizzard's canvas layout drives these three; OnDefault backs the panel's Defaults button.
test("Options panel callbacks", function()
    local anchor = mustLoad()
    local panel = _G.LootToastMoverOptionsPanel
    check(type(panel.OnRefresh) == "function", "OnRefresh is defined")
    check(type(panel.OnCommit) == "function", "OnCommit is defined")
    check(type(panel.OnDefault) == "function", "OnDefault is defined")

    anchor:SetPoint("CENTER", UIParent, "CENTER", 300, 300)
    anchor:GetScript("OnDragStop")(anchor)
    SlashCmdList.LOOTTOASTPOS("minimap")
    check(LootToastMoverDB.point == "CENTER" and LootToastMoverDB.minimapButton.hide == true,
          "position saved and minimap button hidden before restoring defaults")

    panel.OnDefault()
    check(LootToastMoverDB.point == nil, "OnDefault resets the anchor position")
    check(LootToastMoverDB.minimapButton.hide == false, "OnDefault restores the minimap button")
    check(_G.LootToastMoverMinimapButton:IsShown(), "and actually shows it again")

    check(pcall(panel.OnRefresh), "OnRefresh runs without error")
    check(pcall(panel.OnCommit), "OnCommit runs without error")
end)

------------------------------------------------------------------------------------------
-- Broker displays embed LibDataBroker themselves, so the addon looks the library up rather
-- than bundling it. With a bar installed it must register; with none it must not care.
test("Broker plugin", function()
    mustLoad({ broker = true })
    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local dataobj = ldb.objects["LootToastMover"]
    if not check(dataobj ~= nil, "a data object is registered when LibDataBroker is present") then
        return
    end
    check(dataobj.type == "launcher", "it is a launcher, so broker bars show it as a button")
    check(type(dataobj.icon) == "string" and dataobj.icon ~= "", "it has an icon")

    local anchor = _G.LootToastMoverAnchor
    local before = anchor:IsShown()
    dataobj.OnClick(nil, "LeftButton")
    check(anchor:IsShown() ~= before, "clicking the broker button toggles the anchor box")
    dataobj.OnClick(nil, "RightButton")
    check(#Settings.opened == 1, "right-clicking it opens the options panel")

    GameTooltip:SetOwner(nil)
    dataobj.OnTooltipShow(GameTooltip)
    check(GameTooltip.lines[1] == "LootToastMover", "the broker tooltip is titled")
    check(#GameTooltip.lines >= 3, "and explains what the clicks do")
end)

test("Broker plugin is optional", function()
    local anchor, err = loadAddon()
    if check(anchor ~= nil, "the addon still loads with no LibDataBroker anywhere") then
        check(_G.LibStub == nil, "and does not bring a LibStub of its own")
        check(UnboundedTickers() == 0, "and does not sit there retrying forever")
    else
        print("          " .. tostring(err))
    end
end)

------------------------------------------------------------------------------------------
-- /loottoastpos is a long thing to type, which does not help an addon nobody can find.
test("Slash command aliases", function()
    mustLoad()
    check(_G.SLASH_LOOTTOASTPOS1 == "/loottoastpos", "the original command still works")
    check(_G.SLASH_LOOTTOASTPOS2 == "/ltm", "/ltm is registered as a short alias")
end)

------------------------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
