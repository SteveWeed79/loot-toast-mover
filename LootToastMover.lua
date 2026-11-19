
----------------------------------------------------------------------------------------------------
-- LootToastMover ▪ v4.16.0 --------------------------------------------------------------------------
-- Re-anchors Blizzard's AlertFrame (loot toasts, achievements) to a draggable anchor box.
----------------------------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Every string a player reads, in the client's language. See Locales.lua.
local L = ns.L

local DISPLAY_NAME = "LootToastMover"
local ICON = "Interface\\Icons\\inv_misc_bag_10"

-- The exact footprint of LootWonAlertFrameTemplate, so the anchor box is the same size and
-- shape as the toast that will land on it.
local TOAST_WIDTH, TOAST_HEIGHT = 276, 96

local DEFAULT_POINT, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y = "TOP", "TOP", 0, -200

-- Hearthstone. Every character has one, so it always resolves to a valid item link.
local SAMPLE_ITEM_ID = 6948

local function Say(msg)
    print("|cff00c0ff[" .. DISPLAY_NAME .. "]|r " .. msg)
end

------------------------------------------------ Saved variables -----------------------------------
local SCHEMA_VERSION = 2

-- 4.9.x and earlier used a 260x60 box with AlertFrame pinned 56px below its centre. AlertFrame
-- is 10 tall and alerts anchor BOTTOM-to-BOTTOM with it, which put the first toast's bottom
-- edge 31px *below* the box rather than on it. The box is now the toast's real footprint with
-- the toast sitting directly on it, so an existing saved position has to shift to keep toasts
-- where the user actually put them.
local LEGACY_BOX_HEIGHT, LEGACY_TOAST_GAP = 60, 31

local DEFAULT_MINIMAP_ANGLE = 198

-- The anchor points the game accepts. A saved point that is not one of these makes SetPoint
-- raise, at every login, before the rest of the addon has been set up.
local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- A number a frame can be placed with: not NaN and not infinite, both of which a damaged
-- saved-variables file can hold.
local function IsNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function MigratePosition(db)
    if db.schema == SCHEMA_VERSION then return end
    if db.point then
        -- How far the box's bottom edge sits below its anchor point, as a fraction of height.
        local point = tostring(db.point):upper()
        local fraction = 0.5
        if point:find("BOTTOM", 1, true) then
            fraction = 0
        elseif point:find("TOP", 1, true) then
            fraction = 1
        end
        db.yOfs = (db.yOfs or 0) + fraction * (TOAST_HEIGHT - LEGACY_BOX_HEIGHT) - LEGACY_TOAST_GAP
    end
    db.schema = SCHEMA_VERSION
end

-- Retail and Forever list every addon in the Addon Compartment next to the minimap, so a
-- minimap button there is a second copy of the same entry. A new install starts with the
-- button hidden in those games and shown in the Classic ones, which have no compartment.
local function MinimapHiddenByDefault()
    return AddonCompartmentFrame ~= nil
end

-- The saved variables, once they have been checked. Everything below reads this through
-- GetDB() and never touches the LootToastMoverDB global again.
local db

-- Check and repair the saved variables, once. Anything unusable -- from a hand-edit, a
-- crash mid-write, or a much older version -- is put back to its default here, so no code
-- further down has to wonder what it was handed.
local function InitDB()
    local firstRun = type(LootToastMoverDB) ~= "table" or next(LootToastMoverDB) == nil
    if type(LootToastMoverDB) ~= "table" then LootToastMoverDB = {} end
    local saved = LootToastMoverDB

    -- Left over from the LibDBIcon minimap button that the Addon Compartment replaced. The
    -- button below is this addon's own and keeps its state under `minimapButton`, so the
    -- stale LibDBIcon table stays dead weight and is still dropped.
    saved.minimap = nil
    if type(saved.minimapButton) ~= "table" then saved.minimapButton = {} end
    if not IsNumber(saved.minimapButton.angle) then
        saved.minimapButton.angle = DEFAULT_MINIMAP_ANGLE
    end
    -- Anyone who already has the addon keeps the button they are used to seeing; only a
    -- first run takes the per-game default.
    if type(saved.minimapButton.hide) ~= "boolean" then
        saved.minimapButton.hide = firstRun and MinimapHiddenByDefault()
    end

    if saved.point ~= nil then
        local point = type(saved.point) == "string" and saved.point:upper()
        local relPoint = point
        if saved.relPoint ~= nil then
            relPoint = type(saved.relPoint) == "string" and saved.relPoint:upper()
        end
        local x, y = saved.xOfs or 0, saved.yOfs or 0
        if VALID_POINTS[point] and VALID_POINTS[relPoint] and IsNumber(x) and IsNumber(y) then
            saved.point, saved.relPoint, saved.xOfs, saved.yOfs = point, relPoint, x, y
        else
            -- Not a position the game can use, so the box goes back to its default.
            saved.point, saved.relPoint, saved.xOfs, saved.yOfs = nil, nil, nil, nil
        end
    end

    saved.growDown = saved.growDown == true

    MigratePosition(saved)
    db = saved
end

-- Only ever called from ADDON_LOADED onwards, which is the point at which SavedVariables are
-- guaranteed to be in place.
local function GetDB()
    if not db then InitDB() end
    return db
end

------------------------------------------------ Anchor box ----------------------------------------
local anchor = CreateFrame("Frame", "LootToastMoverAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
-- Toasts render above this in every game -- FULLSCREEN_DIALOG in retail and Forever, DIALOG
-- in the Classic games -- so a live toast draws on top of this box rather than disappearing
-- behind it.
anchor:SetFrameStrata("HIGH")

anchor:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false, edgeSize = 12,
    insets   = {left = 3, right = 3, top = 3, bottom = 3},
})
anchor:SetBackdropColor(0, 0, 0, 0.85)
anchor:SetBackdropBorderColor(1, 0.82, 0, 1)

local title = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -10)
title:SetText("|cffffd100" .. DISPLAY_NAME .. "|r")

local body = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
body:SetPoint("CENTER", 0, -2)
-- A translation that runs long wraps inside the box instead of spilling past its edges.
body:SetWidth(TOAST_WIDTH - 24)
body:SetText(L.ANCHOR_DRAG .. "\n" .. L.ANCHOR_LANDS)
body:SetJustifyH("CENTER")

local hint = anchor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOM", 0, 8)
hint:SetText("/ltm test")

anchor:Hide()

-- Escape hides the box, the way it closes any other window. The game hides every frame named
-- in this list when Escape is pressed.
if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "LootToastMoverAnchor")
end

------------------------------------------------ Errors ---------------------------------------------
-- Every function the game calls into is wrapped. An error inside the addon goes to the
-- game's error handler (so BugSack and the like record it with a stack), is mentioned in
-- chat once, and is counted. After a few in one session the addon stops reacting to
-- Blizzard's alert layout until a /reload, because the same fault would otherwise fire on
-- every toast. Saved settings are never touched by any of this.
local ERROR_LIMIT = 3
local errorCount, stoodDown = 0, false

local Restack -- defined with the stacking code below

local function Fail(err)
    errorCount = errorCount + 1
    local handler = geterrorhandler and geterrorhandler()
    if handler then pcall(handler, err) end
    if errorCount == 1 then
        Say(L.ERROR_ONCE:format(tostring(err)))
    end
    if errorCount >= ERROR_LIMIT and not stoodDown then
        stoodDown = true
        -- Any toast hanging downward goes back to Blizzard's own link now: the hook that
        -- keeps it mirrored is about to stop running, and Blizzard's next pass would leave
        -- the frame holding its point and ours together.
        pcall(Restack)
        Say(L.STOOD_DOWN:format(tostring(errorCount)))
    end
end

--- Wrap something the game calls on its own schedule: a hook or a frame script. Does nothing
--- once the addon has stood down.
local function Guarded(fn)
    return function(...)
        if stoodDown then return end
        local ok, err = pcall(fn, ...)
        if not ok then Fail(err) end
    end
end

--- Wrap something the player asked for: a slash command, a click, a menu entry. Still
--- answers after a stand-down, since the commands are how a player finds out what happened.
local function Protected(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then Fail(err) end
    end
end

------------------------------------------------ Helper to snap AlertFrame --------------------------
-- Alerts anchor their BOTTOM to AlertFrame's BOTTOM and stack upward from there (see
-- AlertContainerMixin:UpdateAnchors and GetPointsForJustification, which retail and the
-- Classic games implement the same way). Lining AlertFrame's bottom edge up with the box's
-- means the first toast lands exactly on the box.
local function SnapAlert()
    AlertFrame:ClearAllPoints()
    AlertFrame:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
end

-- Blizzard's managed-frame containers skip any frame carrying this flag. Nothing in the
-- current UI source hands AlertFrame to one, in retail or in Classic Era, so today this is
-- a precaution rather than something the addon depends on.
AlertFrame.ignoreFramePositionManager = true

------------------------------------------------ Stacking downward ----------------------------------
-- Blizzard stacks alerts upward: each one's BOTTOM is anchored to the TOP of the one before
-- it, 10 apart (AlertFrameQueueMixin:AdjustAnchors, and GetPointsForJustification for the
-- frames that place themselves). With the box near the top of the screen that runs a burst
-- of toasts off the top, so the direction can be turned over.
--
-- Nothing of Blizzard's is replaced. After its own layout pass has run, each link in the
-- chain it just built is mirrored: TOP anchored to the BOTTOM of the one before, the same
-- distance apart. The first alert is left alone, so it still lands on the box. With the
-- option off and nothing mirrored, none of this touches a frame.
local MIRROR = {
    BOTTOM = "TOP", BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT",
    TOP = "BOTTOM", TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT",
}

-- Frames currently mirrored, each with the link Blizzard gave it, so that turning the option
-- off puts them back without waiting for the next toast. Weak, because alert frames are
-- pooled and this must not be what keeps one alive.
local mirrored = setmetatable({}, { __mode = "k" })

--- The upward link Blizzard's layout pass set on a frame, if it has one.
local function UpwardLink(frame)
    for i = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        if type(point) == "string" and type(relativePoint) == "string"
            and point:find("^BOTTOM") and relativePoint:find("^TOP") then
            return point, relativeTo, relativePoint, x or 0, y or 0
        end
    end
end

local function RestackFrame(frame, down)
    local point, relativeTo, relativePoint, x, y = UpwardLink(frame)
    if point then
        -- Blizzard's queue adds its point without clearing the frame's others, so a frame
        -- mirrored on the last pass now carries both. Either way it is rebuilt from the
        -- link Blizzard just set.
        local carriesOurs = frame:GetNumPoints() > 1
        if down and relativeTo ~= AlertFrame then
            frame:ClearAllPoints()
            frame:SetPoint(MIRROR[point], relativeTo, MIRROR[relativePoint], x, -y)
            mirrored[frame] = { point, relativeTo, relativePoint, x, y }
        else
            if carriesOurs then
                frame:ClearAllPoints()
                frame:SetPoint(point, relativeTo, relativePoint, x, y)
            end
            mirrored[frame] = nil
        end
    elseif mirrored[frame] and not down then
        -- Switched off between two of Blizzard's passes: put its link back ourselves.
        local link = mirrored[frame]
        frame:ClearAllPoints()
        frame:SetPoint(link[1], link[2], link[3], link[4], link[5])
        mirrored[frame] = nil
    end
end

Restack = function()
    local down = GetDB().growDown and not stoodDown
    if not down and next(mirrored) == nil then return end
    local systems = AlertFrame.alertFrameSubSystems
    if type(systems) ~= "table" then return end
    -- Only frames the alert system positions itself. A frame it merely passes through
    -- (the loot-roll container, the talking head) is positioned by something else and is
    -- left exactly where that put it.
    local autoAnchor = AlertFrameAutoAnchoredMixin and AlertFrameAutoAnchoredMixin.AdjustAnchors
    for _, system in ipairs(systems) do
        local pool = system.alertFramePool
        if pool and pool.EnumerateActive then
            for frame in pool:EnumerateActive() do
                RestackFrame(frame, down)
            end
        elseif autoAnchor and system.AdjustAnchors == autoAnchor
            and system.anchorFrame and system.anchorFrame:IsShown() then
            RestackFrame(system.anchorFrame, down)
        end
    end
end

hooksecurefunc(AlertFrame, "UpdateAnchors", Guarded(function()
    SnapAlert()
    Restack()
end))

local function SetGrowDown(down)
    GetDB().growDown = down and true or false
    Restack()
end

------------------------------------------------ Position helpers ----------------------------------
local function ApplySavedPosition()
    local saved = GetDB()
    anchor:ClearAllPoints()
    if saved.point then
        -- Checked at load, so these are a real anchor point and real numbers.
        anchor:SetPoint(saved.point, UIParent, saved.relPoint, saved.xOfs, saved.yOfs)
    else
        anchor:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y)
    end
    SnapAlert()
end

local function ResetPosition()
    local saved = GetDB()
    saved.point, saved.relPoint, saved.xOfs, saved.yOfs = nil, nil, nil, nil
    anchor:ClearAllPoints()
    anchor:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y)
    SnapAlert()
end

-- Whether the box is on screen only because Edit Mode put it there.
local shownByEditMode = false

local function ToggleAnchor()
    local show = not anchor:IsShown()
    shownByEditMode = false
    anchor:SetShown(show)
    if show then
        -- The box stays until it is dismissed, and it is easy to forget how.
        Say(L.ANCHOR_SHOWN)
    end
end

-- Edit Mode is where the rest of the UI is arranged, so the box is there too: it appears
-- when Edit Mode opens and goes when it closes, unless it was already showing. The events
-- are the ones Blizzard's own frames listen to (EditModeManagerFrame fires them through
-- EventRegistry), so nothing of Edit Mode's is touched. Clients without it never fire them.
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", Guarded(function()
        if not anchor:IsShown() then
            anchor:Show()
            shownByEditMode = true
        end
    end), anchor)
    EventRegistry:RegisterCallback("EditMode.Exit", Guarded(function()
        if shownByEditMode then anchor:Hide() end
        shownByEditMode = false
    end), anchor)
end

------------------------------------------------ Sample toast ---------------------------------------
-- Fires a genuine loot toast through Blizzard's own alert system, so what you see is exactly
-- what a real drop looks like in the position you have chosen.
local function ShowSampleToast()
    if not (LootAlertSystem and Item and Item.CreateFromItemID) then
        Say(L.NO_ALERT_SYSTEM)
        return
    end
    -- C_Item.GetItemInfo returns nil for an item the client has not cached, and
    -- LootWonAlertFrame_SetUp feeds that nil straight into its Azerite and Conduit checks, so
    -- wait for the item data before firing.
    local item = Item:CreateFromItemID(SAMPLE_ITEM_ID)
    item:ContinueOnItemLoad(function()
        LootAlertSystem:AddAlert(item:GetItemLink(), 1)
    end)
end

------------------------------------------------ Drag handling -------------------------------------
anchor:SetScript("OnDragStart", Guarded(function(self)
    self:StartMoving()
end))
anchor:SetScript("OnDragStop", Guarded(function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, xOfs, yOfs = self:GetPoint()
    local saved = GetDB()
    saved.point, saved.relPoint, saved.xOfs, saved.yOfs = point, relPoint, xOfs, yOfs
    SnapAlert()
end))

------------------------------------------------ Shared tooltip text --------------------------------
-- The compartment entry, the minimap button and the broker plugin all describe the same
-- three actions, so they are written once here.
local function FillTooltip(tooltip)
    tooltip:AddLine(DISPLAY_NAME)
    tooltip:AddLine(L.TOOLTIP_CLICK, 1, 1, 1)
    tooltip:AddLine(L.TOOLTIP_RIGHT_CLICK, 1, 1, 1)
    tooltip:AddLine("/ltm test – " .. L.TOOLTIP_TEST, 0.6, 0.6, 0.6)
    tooltip:AddLine("/ltm reset – " .. L.TOOLTIP_RESET, 0.6, 0.6, 0.6)
end

------------------------------------------------ Options panel --------------------------------------
-- Registered into Game Menu → Options → AddOns. Forward-declared because the minimap button
-- and the broker plugin both open it from their right-click handlers, and they are defined
-- first.
local OpenOptions

local optionsCategory
local refreshOptions -- set once the panel is built; syncs widgets with the saved variables

-- 200 fits every English label. A translation that runs longer widens the buttons instead of
-- spilling past their edges.
local BUTTON_WIDTH, BUTTON_HEIGHT, BUTTON_PADDING = 200, 24, 32

local function PanelButton(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(label)
    button:SetScript("OnClick", Protected(onClick))
    return button
end

local function BuildOptionsPanel()
    local panel = CreateFrame("Frame", "LootToastMoverOptionsPanel", UIParent)
    panel.name = DISPLAY_NAME

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(DISPLAY_NAME)

    local blurb = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    blurb:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    blurb:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
    blurb:SetJustifyH("LEFT")
    blurb:SetJustifyV("TOP")
    blurb:SetText(L.PANEL_INTRO)

    local toggleButton = PanelButton(panel, L.BUTTON_TOGGLE, ToggleAnchor)
    toggleButton:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -16)

    local testButton = PanelButton(panel, L.BUTTON_TEST, ShowSampleToast)
    testButton:SetPoint("TOPLEFT", toggleButton, "BOTTOMLEFT", 0, -8)

    local resetButton = PanelButton(panel, L.BUTTON_RESET, function()
        ResetPosition()
        Say(L.POSITION_RESET)
    end)
    resetButton:SetPoint("TOPLEFT", testButton, "BOTTOMLEFT", 0, -8)

    -- One shared width keeps the column straight, however long the widest label is.
    local buttons = { toggleButton, testButton, resetButton }
    local buttonWidth = BUTTON_WIDTH
    for _, button in ipairs(buttons) do
        buttonWidth = math.max(buttonWidth, button:GetTextWidth() + BUTTON_PADDING)
    end
    for _, button in ipairs(buttons) do button:SetWidth(buttonWidth) end

    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -16)

    -- The template's own label is a $parent-named global, which needs the checkbox to be
    -- named; creating the label here keeps both anonymous and the text under our control.
    local checkLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
    checkLabel:SetText(L.CHECK_MINIMAP)

    -- Assigned at the end of the file, once the minimap button exists.
    panel.setMinimapShown = nil

    check:SetScript("OnClick", Protected(function(self)
        local saved = GetDB()
        saved.minimapButton.hide = not self:GetChecked()
        if panel.setMinimapShown then panel.setMinimapShown(not saved.minimapButton.hide) end
    end))

    local stackCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    stackCheck:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -4)

    local stackLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    stackLabel:SetPoint("LEFT", stackCheck, "RIGHT", 2, 0)
    stackLabel:SetText(L.CHECK_STACK_DOWN)

    stackCheck:SetScript("OnClick", Protected(function(self)
        SetGrowDown(self:GetChecked())
    end))

    local commands = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    commands:SetPoint("TOPLEFT", stackCheck, "BOTTOMLEFT", 0, -16)
    commands:SetJustifyH("LEFT")
    commands:SetText(table.concat({
        L.EITHER_COMMAND:format("/ltm", "/loottoastpos") .. " – " .. L.COMMAND_TOGGLE,
        "/ltm test – " .. L.COMMAND_TEST,
        "/ltm reset – " .. L.COMMAND_RESET,
        "/ltm config – " .. L.COMMAND_CONFIG_HERE,
    }, "\n"))

    refreshOptions = function()
        local saved = GetDB()
        check:SetChecked(not saved.minimapButton.hide)
        stackCheck:SetChecked(saved.growDown)
    end

    -- Blizzard's canvas layout calls these when the panel is shown, when Okay is pressed and
    -- when Defaults is pressed. Nothing is staged, so committing is a no-op.
    panel.OnRefresh = Protected(refreshOptions)
    panel.OnCommit = function() end
    panel.OnDefault = Protected(function()
        ResetPosition()
        SetGrowDown(false)
        local saved = GetDB()
        saved.minimapButton.hide = MinimapHiddenByDefault()
        saved.minimapButton.angle = DEFAULT_MINIMAP_ANGLE
        if panel.setMinimapShown then panel.setMinimapShown(not saved.minimapButton.hide) end
        refreshOptions()
    end)

    -- Settings.RegisterAddOnCategory has been the way in since 10.0, and every game the TOC
    -- lists has it, the Classic ones included; the guard is only so a stripped client cannot
    -- break the whole addon.
    if Settings and Settings.RegisterCanvasLayoutCategory then
        optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, DISPLAY_NAME)
        -- Do NOT assign optionsCategory.ID here. The widely copied `category.ID = name`
        -- idiom dates from 10.0, when Settings.OpenToCategory resolved a name. It now
        -- hands the value straight to C_SettingsUtil.OpenSettingsPanel, which takes only
        -- the numeric id the game assigns at registration, so overwriting that id with a
        -- string made every right-click throw "bad argument #1 to 'OpenSettingsPanel'".
        Settings.RegisterAddOnCategory(optionsCategory)
    end

    return panel
end

local optionsPanel = BuildOptionsPanel()

OpenOptions = function()
    if not (optionsCategory and Settings and Settings.OpenToCategory) then
        Say(L.NO_OPTIONS:format(L.USE_COMMANDS))
        return
    end
    -- The id is whatever the game assigned at registration. Clients before 11.x also
    -- resolved the category name, so that is the fallback when there is no numeric id.
    local id = optionsCategory.GetID and optionsCategory:GetID() or optionsCategory.ID
    if type(id) ~= "number" then id = DISPLAY_NAME end
    -- Opening options is a convenience, never worth a Lua error popup: if Blizzard changes
    -- the call again, say so in chat and leave the slash commands working.
    if not pcall(Settings.OpenToCategory, id) then
        Say(L.OPTIONS_FAILED:format(L.USE_COMMANDS))
    end
end

------------------------------------------------ Minimap button -------------------------------------
-- Written directly against the widget API rather than pulled in through LibDBIcon: the whole
-- button is ~60 lines, where the library stack it needs (LibStub, CallbackHandler,
-- LibDataBroker, LibDBIcon) was around 930.
local MINIMAP_BUTTON_SIZE = 31

local minimapButton = CreateFrame("Button", "LootToastMoverMinimapButton", Minimap)
minimapButton:SetSize(MINIMAP_BUTTON_SIZE, MINIMAP_BUTTON_SIZE)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetMovable(true)

local buttonBackground = minimapButton:CreateTexture(nil, "BACKGROUND")
buttonBackground:SetSize(20, 20)
buttonBackground:SetPoint("TOPLEFT", 7, -5)
buttonBackground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local buttonIcon = minimapButton:CreateTexture(nil, "ARTWORK")
buttonIcon:SetSize(17, 17)
buttonIcon:SetPoint("TOPLEFT", 7, -6)
buttonIcon:SetTexture(ICON)

local buttonBorder = minimapButton:CreateTexture(nil, "OVERLAY")
buttonBorder:SetSize(53, 53)
buttonBorder:SetPoint("TOPLEFT", 0, 0)
buttonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

--- Place the button on the minimap's edge at `angle` degrees, measured anticlockwise from
--- the right-hand side the way LibDBIcon does, so a converted position lands where it was.
local function PlaceMinimapButton(angle)
    -- GetWidth can read 0 before the minimap has been laid out; 140 is its default size.
    local width = Minimap:GetWidth()
    local radius = ((width and width > 0) and width or 140) / 2 + 5
    local radians = math.rad(angle)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(radians) * radius, math.sin(radians) * radius)
end

--- Follow the cursor while dragging, converting its position into an angle on the minimap.
local function DragMinimapButton()
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local mx, my = Minimap:GetCenter()
    if not (mx and my and scale and scale > 0) then return end
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    GetDB().minimapButton.angle = angle
    PlaceMinimapButton(angle)
end

minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", Guarded(DragMinimapButton))
end)
minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

-- The minimap button, the broker plugin and the compartment entry all answer a click the
-- same way.
local function OnLauncherClick(_, button)
    if button == "RightButton" then
        OpenOptions()
    else
        ToggleAnchor()
    end
end

minimapButton:SetScript("OnClick", Protected(OnLauncherClick))

minimapButton:SetScript("OnEnter", Protected(function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    FillTooltip(GameTooltip)
    GameTooltip:Show()
end))
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

minimapButton:Hide()

local function SetMinimapButtonShown(shown)
    minimapButton:SetShown(shown and true or false)
end
optionsPanel.setMinimapShown = SetMinimapButtonShown

local function ApplyMinimapButtonState()
    local saved = GetDB()
    PlaceMinimapButton(saved.minimapButton.angle)
    SetMinimapButtonShown(not saved.minimapButton.hide)
end

local function ToggleMinimapButton()
    local saved = GetDB()
    saved.minimapButton.hide = not saved.minimapButton.hide
    SetMinimapButtonShown(not saved.minimapButton.hide)
    if refreshOptions then refreshOptions() end
    return not saved.minimapButton.hide
end

------------------------------------------------ Broker plugin --------------------------------------
-- Broker displays (Titan Panel, Bazooka, ChocolateBar, ElvUI datatexts, …) all embed
-- LibDataBroker themselves, so the library is already loaded whenever there is a bar to
-- appear on. Looking it up instead of bundling it keeps this addon dependency-free: with no
-- broker bar installed there is simply nothing to register with, and the minimap button and
-- Addon Compartment entry still cover the same ground.
local brokerRegistered = false

local function RegisterBroker()
    if brokerRegistered or not LibStub then return false end
    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then return false end

    ldb:NewDataObject(DISPLAY_NAME, {
        type = "launcher",
        icon = ICON,
        label = DISPLAY_NAME,
        OnClick = Protected(OnLauncherClick),
        OnTooltipShow = Protected(function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            FillTooltip(tooltip)
        end),
    })
    brokerRegistered = true
    return true
end

------------------------------------------------ Addon Compartment ----------------------------------
-- Registered declaratively from the TOC, which is why these have to be globals. Blizzard calls
-- them as func(addonName, buttonName) and func(addonName, button); see
-- Blizzard_Minimap/Mainline/AddonCompartment.lua. Only retail and Forever have a compartment.
-- The Classic games ignore these TOC fields, and the minimap button covers the same ground.

LootToastMover_OnCompartmentClick = Protected(OnLauncherClick)

LootToastMover_OnCompartmentEnter = Protected(function(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    FillTooltip(GameTooltip)
    GameTooltip:Show()
end)

LootToastMover_OnCompartmentLeave = Protected(function()
    GameTooltip:Hide()
end)

------------------------------------------------ Slash cmd -----------------------------------------
SLASH_LOOTTOASTPOS1 = "/loottoastpos"
SLASH_LOOTTOASTPOS2 = "/ltm"
SlashCmdList.LOOTTOASTPOS = Protected(function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "reset" then
        ResetPosition()
        Say(L.POSITION_RESET)
    elseif cmd == "test" then
        ShowSampleToast()
    elseif cmd == "config" or cmd == "options" then
        OpenOptions()
    elseif cmd == "minimap" then
        Say(ToggleMinimapButton() and L.MINIMAP_SHOWN or L.MINIMAP_HIDDEN)
    elseif cmd == "" then
        ToggleAnchor()
    else
        -- The commands themselves are typed in English in every client; only what they do is
        -- translated.
        Say(L.USAGE)
        for _, usage in ipairs({
            { "/ltm", L.COMMAND_TOGGLE },
            { "/ltm test", L.COMMAND_TEST },
            { "/ltm reset", L.COMMAND_RESET },
            { "/ltm config", L.COMMAND_CONFIG },
            { "/ltm minimap", L.COMMAND_MINIMAP },
        }) do
            print(("  |cffffd100%s|r – %s"):format(usage[1], usage[2]))
        end
    end
end)

------------------------------------------------ Init ----------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", Protected(function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName ~= ADDON_NAME then return end
        -- Unregistered first, so that a fault in any one step below cannot leave the
        -- handler running again for every addon that loads after this one.
        self:UnregisterEvent(event)
        InitDB()
        ApplySavedPosition()
        ApplyMinimapButtonState()
        if refreshOptions then refreshOptions() end
    elseif event == "PLAYER_LOGIN" then
        -- Every addon has loaded by now, so a broker display's copy of LibDataBroker is in
        -- place if there is one. One attempt, no retry ticker.
        RegisterBroker()
        self:UnregisterEvent(event)
    end
end))
