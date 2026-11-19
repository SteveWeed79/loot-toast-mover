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

-- The private table the last loadAddon shared between the addon's files, as the client does.
local loadedNamespace

--- Load the addon the way the client would: every file the TOC lists, in order.
-- @param opts.savedVars a table to install as LootToastMoverDB before loading
-- @param opts.broker install LibStub + LibDataBroker first, as a broker display would
-- @param opts.compartment give the client an Addon Compartment, as retail and Forever have
-- @param opts.before runs after the stub is reset and before the addon's files load
-- @param opts.locale the client language GetLocale reports, "enUS" if not given
-- @param opts.wrapStrings replaces the string table once Locales.lua has built it
-- @return the anchor frame, or nil plus the error that stopped the load
local function loadAddon(opts)
    opts = opts or {}
    stub.reset()
    if opts.locale then stub.locale = opts.locale end
    if opts.savedVars then _G.LootToastMoverDB = opts.savedVars end
    if opts.broker then InstallBrokerLibs() end
    if opts.compartment then _G.AddonCompartmentFrame = {} end
    if opts.before then opts.before() end

    local namespace = {}
    loadedNamespace = namespace
    for _, rel in ipairs(tocFiles()) do
        local chunk, loadErr = loadfile(ADDON_DIR .. "/" .. rel)
        if not chunk then return nil, loadErr end
        -- WoW passes each file the addon's name and one table that all its files share.
        local ok, err = pcall(chunk, "LootToastMover", namespace)
        if not ok then return nil, err end
        if opts.wrapStrings and rel == "Locales.lua" then
            namespace.L = opts.wrapStrings(namespace.L)
        end
    end

    FireEvent("ADDON_LOADED", "LootToastMover")
    FireEvent("PLAYER_LOGIN")
    TickAll(3)
    _G.CHAT = {}
    return _G.LootToastMoverAnchor
end

--- Leave a frame where a drag would: the client's StartMoving/StopMovingOrSizing replaces a
--- frame's points with a single one, so the old points are cleared first.
local function moveTo(frame, x, y)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
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
    moveTo(anchor, 123, -45)
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
    moveTo(anchor, 10, 20)
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
    moveTo(anchor, 1, 2)
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
-- Regression, shipped in 4.11.0: the addon overwrote the category's numeric id with the
-- addon name, copying an idiom that worked when Settings.OpenToCategory still resolved a
-- name. It now forwards the value to C_SettingsUtil.OpenSettingsPanel, which takes an
-- integer, so every right-click on the minimap button threw a Lua error instead of opening
-- anything. The id the game assigns has to be left exactly as it is.
test("Opening options uses the id the game assigned", function()
    mustLoad()
    local category = Settings.categories[1]
    check(type(category:GetID()) == "number", "the addon did not overwrite the category id")
    check(category.ID ~= "LootToastMover", "the id is not the addon name")

    -- Every route into the options panel has to survive, not just the slash command.
    local routes = {
        ["/ltm config"] = function() SlashCmdList.LOOTTOASTPOS("config") end,
        ["minimap right-click"] = function()
            local button = _G.LootToastMoverMinimapButton
            button:GetScript("OnClick")(button, "RightButton")
        end,
        ["compartment right-click"] = function()
            LootToastMover_OnCompartmentClick("LootToastMover", "RightButton")
        end,
    }
    for name, open in pairs(routes) do
        local before = #Settings.opened
        local ok, err = pcall(open)
        check(ok, name .. " does not error" .. (ok and "" or ": " .. tostring(err)))
        check(#Settings.opened == before + 1, name .. " opens the panel")
        check(type(Settings.opened[#Settings.opened]) == "number",
              name .. " passes a numeric category id")
    end
end)

------------------------------------------------------------------------------------------
-- Opening options is a convenience. If Blizzard changes the call again it must degrade to a
-- chat line, not a Lua error popup every time someone right-clicks the minimap button.
test("A broken OpenToCategory does not throw", function()
    mustLoad()
    Settings.OpenToCategory = function() error("simulated Blizzard API change", 2) end

    _G.CHAT = {}
    local button = _G.LootToastMoverMinimapButton
    local ok = pcall(button:GetScript("OnClick"), button, "RightButton")
    check(ok, "right-click still does not error")
    check(#_G.CHAT > 0, "it explains itself in chat instead")
end)

------------------------------------------------------------------------------------------
-- Blizzard's canvas layout drives these three; OnDefault backs the panel's Defaults button.
test("Options panel callbacks", function()
    local anchor = mustLoad()
    local panel = _G.LootToastMoverOptionsPanel
    check(type(panel.OnRefresh) == "function", "OnRefresh is defined")
    check(type(panel.OnCommit) == "function", "OnCommit is defined")
    check(type(panel.OnDefault) == "function", "OnDefault is defined")

    moveTo(anchor, 300, 300)
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
-- Translations. English is the source of every string, and every other client language
-- replaces what it translates. These sections stop a new string, or a new language, from
-- shipping half-done.

-- Every language a WoW client runs in besides English. esMX and ptPT share the Spanish and
-- Portuguese tables, and are checked too, to prove the sharing holds.
local LANGUAGES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ptPT", "ruRU",
                    "zhCN", "zhTW" }

--- The string table one client language sees, and the English behind it.
local function stringsFor(locale)
    stub.reset()
    stub.locale = locale
    local namespace = {}
    assert(loadfile(ADDON_DIR .. "/Locales.lua"))("LootToastMover", namespace)
    return namespace.L, getmetatable(namespace.L).__index
end

--- How many times `needle` appears in `text`, as plain text.
local function occurrences(text, needle)
    local count, from = 0, 1
    while true do
        local _, last = text:find(needle, from, true)
        if not last then return count end
        count, from = count + 1, last + 1
    end
end

--- ", missing A, B" for a check's label, or "" when the list is empty.
local function listed(label, items)
    table.sort(items)
    return #items > 0 and ("; %s %s"):format(label, table.concat(items, ", ")) or ""
end

test("Every language translates every string, and nothing else", function()
    local _, english = stringsFor("enUS")
    for _, locale in ipairs(LANGUAGES) do
        local L = stringsFor(locale)
        local missing, unknown = {}, {}
        for key in pairs(english) do
            if rawget(L, key) == nil then table.insert(missing, key) end
        end
        for key in pairs(L) do
            if english[key] == nil then table.insert(unknown, key) end
        end
        check(#missing == 0, locale .. " translates every string" .. listed("missing", missing))
        check(#unknown == 0, locale .. " has no strings English lacks" .. listed("unknown", unknown))
    end
end)

-- Each of these has to come through translation unchanged: string.format fills in %s, and the
-- commands are typed in English in every client. No English string has a line break, and a
-- translation must not add one: the anchor box only has room for its two lines, and a newline
-- may not survive CurseForge's translation tool.
local MUST_SURVIVE = { "%s", "/ltm test", "/ltm reset", "/loottoastpos", "/ltm", "\n" }

test("Translations keep placeholders, commands and line breaks", function()
    local _, english = stringsFor("enUS")
    for _, locale in ipairs(LANGUAGES) do
        local L = stringsFor(locale)
        local broken = {}
        for key, source in pairs(english) do
            local text = rawget(L, key)
            if text then
                for _, token in ipairs(MUST_SURVIVE) do
                    if occurrences(text, token) ~= occurrences(source, token) then
                        table.insert(broken, ("%s (%s)"):format(key,
                            token == "\n" and "line break" or token))
                    end
                end
                -- Any other % would break string.format wherever the string is the format.
                if text:gsub("%%s", ""):find("%", 1, true) then
                    table.insert(broken, key .. " (stray %)")
                end
                if not text:find("%S") then table.insert(broken, key .. " (empty)") end
            end
        end
        check(#broken == 0, locale .. " keeps them all" .. listed("broken:", broken))
    end
end)

test("English clients, and any language without a table, read English", function()
    for _, locale in ipairs({ "enUS", "enGB", "xxXX" }) do
        local L, english = stringsFor(locale)
        local same = next(english) ~= nil
        for key, text in pairs(english) do
            if L[key] ~= text then same = false end
        end
        check(same, locale .. " reads every string in English")
        check(next(L) == nil, locale .. " carries no translations of its own")
    end
end)

test("A string a language has not translated falls back to English", function()
    local L, english = stringsFor("deDE")
    rawset(L, "USAGE", nil)
    check(L.USAGE == english.USAGE, "an untranslated string reads as English, not nil")
end)

test("The code asks only for strings that exist, and uses all of them", function()
    local _, english = stringsFor("enUS")
    local fh = assert(io.open(ADDON_DIR .. "/LootToastMover.lua"))
    local source = fh:read("*a")
    fh:close()
    local used, unknown, unused = {}, {}, {}
    for key in source:gmatch("%f[%w_]L%.([%w_]+)") do
        used[key] = true
        if english[key] == nil then table.insert(unknown, key) end
    end
    for key in pairs(english) do
        if not used[key] then table.insert(unused, key) end
    end
    check(#unknown == 0, "every L.KEY in the addon has an English string" .. listed("unknown", unknown))
    check(#unused == 0, "every English string is used, so none is translated for nothing"
        .. listed("unused", unused))
end)

-- Pseudo-localisation: every string comes back wrapped in markers, so text that turns up
-- without them was written into the code in English, where no translation can reach it.
test("Every string the addon shows goes through the translations", function()
    local function wrap(L)
        return setmetatable({}, { __index = function(_, key)
            local text = L[key]
            if text == nil then error("no string named " .. tostring(key), 2) end
            return "⟦" .. text .. "⟧"
        end })
    end
    local anchor = mustLoad({ wrapStrings = wrap })

    local shown = {}
    local function collect(texts)
        for _, text in ipairs(texts) do table.insert(shown, text) end
    end
    collect(stub.texts(anchor))
    collect(stub.texts(_G.LootToastMoverOptionsPanel))
    LootToastMover_OnCompartmentEnter("LootToastMover", { _name = "CompartmentButton" })
    collect(GameTooltip.lines)

    -- Every chat message, the ones only a failure produces included.
    _G.CHAT = {}
    for _, cmd in ipairs({ "bogus", "reset", "minimap", "minimap" }) do
        SlashCmdList.LOOTTOASTPOS(cmd)
    end
    Settings.OpenToCategory = function() error("simulated Blizzard API change", 2) end
    SlashCmdList.LOOTTOASTPOS("config")
    Settings.OpenToCategory = nil
    SlashCmdList.LOOTTOASTPOS("config")
    _G.LootAlertSystem = nil
    SlashCmdList.LOOTTOASTPOS("test")
    collect(_G.CHAT)

    -- The addon's name and its commands read the same in every language.
    local untranslated = { ["LootToastMover"] = true, ["|cffffd100LootToastMover|r"] = true,
                           ["/ltm test"] = true }
    local leaks = {}
    for _, text in ipairs(shown) do
        for line in (text .. "\n"):gmatch("(.-)\n") do
            if not untranslated[line] and not line:find("⟦", 1, true)
                    and not line:find("⟧", 1, true) then
                table.insert(leaks, line)
            end
        end
    end
    check(#shown >= 25, ("the check saw everything the addon shows (%d texts)"):format(#shown))
    check(#leaks == 0, "no English text gets past the translations" .. listed("leaked:", leaks))
end)

test("Each language shows its own text", function()
    local _, english = stringsFor("enUS")
    for _, locale in ipairs(LANGUAGES) do
        local anchor = mustLoad({ locale = locale })
        local L = loadedNamespace.L
        local function shows(texts, wanted)
            for _, text in ipairs(texts) do
                if text == wanted then return true end
            end
            return false
        end
        local panel = stub.texts(_G.LootToastMoverOptionsPanel)
        LootToastMover_OnCompartmentEnter("LootToastMover", { _name = "CompartmentButton" })
        _G.CHAT = {}
        SlashCmdList.LOOTTOASTPOS("reset")
        check(L.ANCHOR_DRAG ~= english.ANCHOR_DRAG
                  and shows(stub.texts(anchor), L.ANCHOR_DRAG .. "\n" .. L.ANCHOR_LANDS)
                  and shows(panel, L.PANEL_INTRO) and shows(panel, L.BUTTON_TOGGLE)
                  and shows(panel, L.CHECK_MINIMAP) and GameTooltip.lines[2] == L.TOOLTIP_CLICK
                  and (_G.CHAT[1] or ""):find(L.POSITION_RESET, 1, true) ~= nil,
              locale .. ": the anchor box, options panel, tooltip and chat are in " .. locale)
    end
end)

test("Option buttons widen for a long translation, and stay one width", function()
    for _, locale in ipairs({ "enUS", unpack(LANGUAGES) }) do
        mustLoad({ locale = locale })
        local buttons = stub.children(_G.LootToastMoverOptionsPanel, "Button")
        local fits = #buttons == 3
        for _, button in ipairs(buttons) do
            -- Room for the template's rounded ends on both sides of the label.
            if button:GetWidth() < 200 or button:GetWidth() - button:GetTextWidth() < 24
                    or button:GetWidth() ~= buttons[1]:GetWidth() then
                fits = false
            end
        end
        check(fits, ("%s: every label fits, and the three buttons share one width (%d)")
            :format(locale, buttons[1] and buttons[1]:GetWidth() or 0))
        if locale == "enUS" then
            check(buttons[1]:GetWidth() == 200, "English keeps the original 200 wide buttons")
        end
    end
end)

-- tools/upload_translations.sh sends this export to CurseForge, so it has to come back as
-- exactly the strings it was made from: every phrase, nothing mangled on the way.
test("The CurseForge export reads back as exactly the strings it came from", function()
    local lua = arg and arg[-1] or "lua5.1"
    local exporter = here .. "/../tools/export_locale.lua"
    for _, locale in ipairs({ "enUS", unpack(LANGUAGES) }) do
        local L, english = stringsFor(locale)
        local expected = locale == "enUS" and english or L
        local pipe = assert(io.popen(("%s %q %s"):format(lua, exporter, locale)))
        local exported = pipe:read("*a")
        pipe:close()
        -- Load the export as CurseForge would read it: assignments into a table named L.
        local loaded = {}
        local chunk = loadstring(exported)
        local ok = chunk ~= nil
        if ok then
            setfenv(chunk, { L = loaded })
            ok = pcall(chunk)
        end
        local same = ok and next(loaded) ~= nil
        for key, text in pairs(expected) do
            if loaded[key] ~= text then same = false end
        end
        for key in pairs(loaded) do
            if rawget(expected, key) == nil then same = false end
        end
        check(same, locale .. " exports every phrase exactly, and loads back as Lua")
    end
end)

test("The addon list description is translated too", function()
    local notes = {}
    for line in io.lines(ADDON_DIR .. "/LootToastMover.toc") do
        local locale, text = line:match("^##%s*Notes%-(%a+)%s*:%s*(.-)%s*$")
        if locale then notes[locale] = text end
    end
    for _, locale in ipairs(LANGUAGES) do
        check((notes[locale] or "") ~= "", "## Notes-" .. locale .. " is there")
    end
end)

------------------------------------------------------------------------------------------
-- A saved position is handed to SetPoint, which raises on anything it does not recognise.
-- Unchecked, a damaged saved-variables file raised at every login and skipped everything
-- the load handler does after placing the box, the minimap button included.
test("A damaged saved position falls back to the default instead of raising", function()
    local cases = {
        { "a point that is not one",
          { point = "MIDDLE", relPoint = "CENTER", xOfs = 1, yOfs = 2, schema = 2 } },
        { "a relative point that is not one",
          { point = "CENTER", relPoint = 7, xOfs = 1, yOfs = 2, schema = 2 } },
        { "an offset that is text",
          { point = "CENTER", relPoint = "CENTER", xOfs = "left", yOfs = 2, schema = 2 } },
        { "an offset that is not a number",
          { point = "CENTER", relPoint = "CENTER", xOfs = 0 / 0, yOfs = 2, schema = 2 } },
        { "an infinite offset",
          { point = "CENTER", relPoint = "CENTER", xOfs = 1, yOfs = math.huge, schema = 2 } },
    }
    for _, case in ipairs(cases) do
        local anchor, err = loadAddon({ savedVars = case[2] })
        if check(anchor ~= nil, case[1] .. ": the addon still loads") then
            check(anchor:GetPoint() == "TOP", case[1] .. ": the box is at its default position")
            check(LootToastMoverDB.point == nil, case[1] .. ": the bad position is dropped")
            check(#ERRORS == 0, case[1] .. ": no error is raised")
            check(LootToastMoverMinimapButton:IsShown(), case[1] .. ": the minimap button is still set up")
        else
            print("          " .. tostring(err))
        end
    end

    -- Good positions are untouched, and a lower-case point is tidied rather than thrown away.
    local anchor = mustLoad({ savedVars = { point = "bottomleft", xOfs = 40, yOfs = 60, schema = 2 } })
    local point, _, relPoint, x, y = anchor:GetPoint()
    check(point == "BOTTOMLEFT" and relPoint == "BOTTOMLEFT" and x == 40 and y == 60,
          "a usable position survives, whatever its case")

    -- Saved variables that are not a table at all, or hold a broken minimap table.
    check(loadAddon({ before = function() _G.LootToastMoverDB = "oops" end }) ~= nil,
          "saved variables that are not a table are started again")
    mustLoad({ savedVars = { minimapButton = { angle = 0 / 0, hide = "yes" }, schema = 2 } })
    check(LootToastMoverDB.minimapButton.angle == 198 and LootToastMoverDB.minimapButton.hide == false,
          "a broken minimap entry goes back to its defaults")
end)

------------------------------------------------------------------------------------------
-- The saved variables used to be re-checked and re-migrated on every read, once per frame
-- while the minimap button was being dragged.
test("Saved variables are checked once, at load", function()
    mustLoad()
    -- Break the table after load. A second check would repair this; a single one leaves it.
    _G.LootToastMoverDB.minimap = { stale = true }
    SlashCmdList.LOOTTOASTPOS("minimap")
    SlashCmdList.LOOTTOASTPOS("minimap")
    check(LootToastMoverDB.minimap ~= nil, "later reads do not re-run the load-time clean-up")
end)

------------------------------------------------------------------------------------------
-- Every function the game calls into is wrapped: an error is handed to the error handler,
-- mentioned in chat once, and counted, and after three the addon stops reacting to the alert
-- layout rather than raising on every toast.
test("An error inside the addon is contained, reported once and counted", function()
    local anchor = mustLoad()
    local realClear = AlertFrame.ClearAllPoints
    AlertFrame.ClearAllPoints = function() error("alert frame exploded") end

    check(pcall(AlertFrame.UpdateAnchors, AlertFrame), "the layout hook does not raise into Blizzard's code")
    check(#ERRORS == 1 and ERRORS[1]:find("alert frame exploded", 1, true) ~= nil,
          "the error reaches the error handler")
    check(#CHAT == 1 and CHAT[1]:find("alert frame exploded", 1, true) ~= nil, "chat hears about it once")

    AlertFrame:UpdateAnchors()
    check(#CHAT == 1, "a second error is counted but not announced again")
    AlertFrame:UpdateAnchors()
    check(#ERRORS == 3 and #CHAT == 2 and CHAT[2]:find("/reload", 1, true) ~= nil,
          "the third stands the addon down and says how to restart it")

    AlertFrame.ClearAllPoints = realClear
    local calls = #ERRORS
    AlertFrame:UpdateAnchors()
    check(#ERRORS == calls, "stood down, the hook no longer runs")

    -- What the player asks for still answers.
    _G.CHAT = {}
    check(pcall(SlashCmdList.LOOTTOASTPOS, "help"), "slash commands still answer")
    check(#CHAT > 0, "and still print")
    SlashCmdList.LOOTTOASTPOS("")
    check(anchor:IsShown(), "the box can still be shown")
end)

test("Slash commands, the compartment and the minimap button do not raise", function()
    mustLoad()
    local realShow = GameTooltip.Show
    GameTooltip.Show = function() error("tooltip exploded") end
    check(pcall(LootToastMover_OnCompartmentEnter, "LootToastMover", {}),
          "the compartment tooltip is contained")
    check(pcall(LootToastMoverMinimapButton:GetScript("OnEnter"), LootToastMoverMinimapButton),
          "the minimap tooltip is contained")
    GameTooltip.Show = realShow
    check(#ERRORS == 2, "both were counted")

    local realAdd = LootAlertSystem.AddAlert
    LootAlertSystem.AddAlert = function() error("alert exploded") end
    check(pcall(SlashCmdList.LOOTTOASTPOS, "test"), "the slash command returns")
    LootAlertSystem.AddAlert = realAdd
end)

------------------------------------------------------------------------------------------
-- Blizzard stacks alerts upward. With the box near the top of the screen a burst of toasts
-- ran off the top, so the direction can be turned over. Nothing of Blizzard's is replaced:
-- each link its layout pass builds is mirrored afterwards.
local function linkOf(frame)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    return ("%s>%s:%s %d,%d"):format(point, relativeTo._name, relativePoint, x, y)
end

test("Toasts stack upward unless asked, and the alert frames are left alone", function()
    mustLoad()
    local queue = AddAlertQueue()
    local first, second = queue:Add("first"), queue:Add("second")
    check(linkOf(first) == "BOTTOM>AlertFrame:TOP 0,10", "the first toast sits on AlertFrame")
    check(linkOf(second) == "BOTTOM>first:TOP 0,10", "the second sits above the first")
    check(first:GetNumPoints() == 1 and second:GetNumPoints() == 1, "each still has only Blizzard's point")
    check(LootToastMoverDB.growDown == false, "stacking downward is off by default")
end)

test("Stacking downward mirrors every link but the first", function()
    mustLoad({ savedVars = { growDown = true, schema = 2 } })
    local queue = AddAlertQueue()
    local first, second, third = queue:Add("first"), queue:Add("second"), queue:Add("third")

    check(linkOf(first) == "BOTTOM>AlertFrame:TOP 0,10", "the first toast still lands on the box")
    check(linkOf(second) == "TOP>first:BOTTOM 0,-10", "the second hangs below the first")
    check(linkOf(third) == "TOP>second:BOTTOM 0,-10", "the third below the second")
    check(second:GetNumPoints() == 1 and third:GetNumPoints() == 1,
          "no frame is left holding both Blizzard's point and the mirrored one")

    -- Blizzard re-lays out on every alert, adding its point to whatever the frame has.
    AlertFrame:UpdateAnchors()
    AlertFrame:UpdateAnchors()
    check(linkOf(third) == "TOP>second:BOTTOM 0,-10" and third:GetNumPoints() == 1,
          "repeated layout passes leave one clean point")

    -- The oldest toast finishes: the next one becomes the first and goes back on the box.
    queue:Release(first)
    check(linkOf(second) == "BOTTOM>AlertFrame:TOP 0,10" and second:GetNumPoints() == 1,
          "a toast promoted to first sits on the box again")
    check(linkOf(third) == "TOP>second:BOTTOM 0,-10", "and the rest still hang below it")
end)

test("Turning stacking downward off puts every toast back at once", function()
    mustLoad()
    local queue = AddAlertQueue()
    local first, second = queue:Add("first"), queue:Add("second")
    local stackCheck = stub.children(LootToastMoverOptionsPanel, "CheckButton")[2]

    stackCheck:SetChecked(true)
    stackCheck:GetScript("OnClick")(stackCheck)
    check(LootToastMoverDB.growDown == true, "the checkbox saves the choice")
    check(linkOf(second) == "TOP>first:BOTTOM 0,-10",
          "toasts on screen turn over without waiting for the next one")

    stackCheck:SetChecked(false)
    stackCheck:GetScript("OnClick")(stackCheck)
    check(linkOf(second) == "BOTTOM>first:TOP 0,10" and second:GetNumPoints() == 1,
          "and turn back the same way")
    check(linkOf(first) == "BOTTOM>AlertFrame:TOP 0,10", "the first never moved")

    stackCheck:SetChecked(true)
    stackCheck:GetScript("OnClick")(stackCheck)
    LootToastMoverOptionsPanel.OnDefault()
    check(LootToastMoverDB.growDown == false and linkOf(second) == "BOTTOM>first:TOP 0,10",
          "Defaults turns it off again")
    check(stackCheck:GetChecked() == false, "and the checkbox follows")
end)

test("Standing down hands downward toasts back to Blizzard's layout", function()
    mustLoad({ savedVars = { growDown = true, schema = 2 } })
    local queue = AddAlertQueue()
    local first, second = queue:Add("first"), queue:Add("second")
    check(linkOf(second) == "TOP>first:BOTTOM 0,-10", "hanging downward to begin with")

    local realClear = AlertFrame.ClearAllPoints
    AlertFrame.ClearAllPoints = function() error("alert frame exploded") end
    for _ = 1, 3 do AlertFrame:UpdateAnchors() end
    AlertFrame.ClearAllPoints = realClear

    AlertFrame:UpdateAnchors()
    check(linkOf(second) == "BOTTOM>first:TOP 0,10" and second:GetNumPoints() == 1,
          "the toast is back on Blizzard's link, and only that")
    check(first:GetNumPoints() == 1, "and so is the first")
    check(LootToastMoverDB.growDown == true, "the saved choice is kept for after a /reload")
end)

test("Stacking downward moves only frames the alert system places itself", function()
    mustLoad({ savedVars = { growDown = true, schema = 2 } })
    local queue = AddAlertQueue()
    local rolls = AddAlertAnchorFrame("external", "GroupLootContainer")
    rolls:SetPoint("BOTTOM", UIParent, "TOP", 0, -400)
    local selfPlaced = AddAlertAnchorFrame("auto", "SelfPlaced")
    local later = AddAlertQueue()

    local toast = queue:Add("toast")
    local after = later:Add("after")
    check(linkOf(rolls) == "BOTTOM>UIParent:TOP 0,-400",
          "a frame the system only passes through is not touched, whatever its points look like")
    check(linkOf(selfPlaced) == "TOP>GroupLootContainer:BOTTOM 0,0", "a frame that places itself is mirrored")
    check(linkOf(after) == "TOP>SelfPlaced:BOTTOM 0,-10", "and so is the toast after it")
    check(linkOf(toast) == "BOTTOM>AlertFrame:TOP 0,10", "the first toast stays on the box")
end)

------------------------------------------------------------------------------------------
-- Retail and Forever already list the addon in the Addon Compartment, so a minimap button
-- there is a second copy of the same entry. Only a first run takes the new default.
test("The minimap button starts hidden only where there is an Addon Compartment", function()
    mustLoad({ compartment = true })
    check(not LootToastMoverMinimapButton:IsShown(),
          "a first run with a compartment starts without the button")
    SlashCmdList.LOOTTOASTPOS("minimap")
    check(LootToastMoverMinimapButton:IsShown(), "/ltm minimap still brings it back")

    mustLoad()
    check(LootToastMoverMinimapButton:IsShown(),
          "a first run without one shows it, as the Classic games need")

    mustLoad({ compartment = true, savedVars = { schema = 2, minimapButton = { angle = 10 } } })
    check(LootToastMoverMinimapButton:IsShown(), "an existing install keeps the button it had")

    mustLoad({ compartment = true, savedVars = { schema = 2, minimapButton = { angle = 10, hide = false } } })
    LootToastMoverOptionsPanel.OnDefault()
    check(not LootToastMoverMinimapButton:IsShown(), "Defaults follows the game it is running in")
end)

------------------------------------------------------------------------------------------
test("The box appears with Edit Mode and goes with it", function()
    local anchor = mustLoad()
    EventRegistry:TriggerEvent("EditMode.Enter")
    check(anchor:IsShown(), "entering Edit Mode shows the box")
    check(#CHAT == 0, "without the chat reminder, which is for the slash command")
    EventRegistry:TriggerEvent("EditMode.Exit")
    check(not anchor:IsShown(), "leaving hides it again")

    SlashCmdList.LOOTTOASTPOS("")
    EventRegistry:TriggerEvent("EditMode.Enter")
    EventRegistry:TriggerEvent("EditMode.Exit")
    check(anchor:IsShown(), "a box the player had already shown is left showing")

    SlashCmdList.LOOTTOASTPOS("")
    EventRegistry:TriggerEvent("EditMode.Enter")
    SlashCmdList.LOOTTOASTPOS("")
    SlashCmdList.LOOTTOASTPOS("")
    EventRegistry:TriggerEvent("EditMode.Exit")
    check(anchor:IsShown(), "and one re-shown by hand during Edit Mode is the player's again")

    check(loadAddon({ before = function() _G.EventRegistry = nil end }) ~= nil,
          "a client without the registry still loads")
end)

test("Escape hides the box, and showing it says how to hide it", function()
    local anchor = mustLoad()
    SlashCmdList.LOOTTOASTPOS("")
    check(anchor:IsShown(), "shown")
    check(#CHAT == 1 and CHAT[1]:find("/ltm", 1, true) ~= nil and CHAT[1]:find("Escape", 1, true) ~= nil,
          "chat says how to hide it")
    PressEscape()
    check(not anchor:IsShown(), "Escape hides it")
    _G.CHAT = {}
    SlashCmdList.LOOTTOASTPOS("")
    SlashCmdList.LOOTTOASTPOS("")
    check(#CHAT == 1, "hiding it says nothing")

    check(loadAddon({ before = function() _G.UISpecialFrames = nil end }) ~= nil,
          "a client without the list still loads")
end)

test("The sample toast needs the item loader as well as the alert system", function()
    mustLoad({ before = function() _G.Item = nil end })
    check(pcall(SlashCmdList.LOOTTOASTPOS, "test"), "no error without it")
    check(#CHAT == 1 and #ERRORS == 0, "just the chat line saying it is not available")
end)

------------------------------------------------------------------------------------------
-- The stub is only worth anything if it is strict. A permissive one returns a no-op for
-- any method name, so a typo or a widget method Blizzard has removed sails through the
-- whole suite and only surfaces on someone's login screen. Guard that property here, since
-- nothing else would notice it being relaxed.
test("The stub rejects widget methods that do not exist", function()
    stub.reset()
    local frame = CreateFrame("Frame", "StrictnessProbe", UIParent)

    local bogus = { "SetPointy", "SetBackdropBorderColour", "ThisMethodDoesNotExist" }
    for _, name in ipairs(bogus) do
        local ok, err = pcall(function() return frame[name] end)
        check(not ok, ("%s is rejected"):format(name))
        if not ok then
            check(tostring(err):find("not a modelled widget method", 1, true) ~= nil,
                  ("%s reports why"):format(name))
        end
    end

    -- Modelled methods and the stub's own bookkeeping still work.
    check(pcall(function() return frame.SetPoint end), "modelled methods are reachable")
    check(pcall(function() return frame.SetBackdrop end), "allowlisted real methods are reachable")
    check(frame._nothingHere == nil, "unset underscore fields read as nil, not an error")
end)

------------------------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
