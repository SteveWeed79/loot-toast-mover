
----------------------------------------------------------------------------------------------------
-- LootToastMover ▪ v4.11.2 --------------------------------------------------------------------------
-- Re-anchors Blizzard's AlertFrame (loot toasts, achievements) to a draggable anchor box.
----------------------------------------------------------------------------------------------------
local ADDON_NAME = ...

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

-- Only ever called from ADDON_LOADED onwards, which is the point at which SavedVariables are
-- guaranteed to be in place.
local function GetDB()
    if type(LootToastMoverDB) ~= "table" then LootToastMoverDB = {} end
    -- Left over from the LibDBIcon minimap button that the Addon Compartment replaced. The
    -- button below is this addon's own and keeps its state under `minimapButton`, so the
    -- stale LibDBIcon table stays dead weight and is still dropped.
    LootToastMoverDB.minimap = nil
    if type(LootToastMoverDB.minimapButton) ~= "table" then
        LootToastMoverDB.minimapButton = {}
    end
    if type(LootToastMoverDB.minimapButton.angle) ~= "number" then
        LootToastMoverDB.minimapButton.angle = DEFAULT_MINIMAP_ANGLE
    end
    MigratePosition(LootToastMoverDB)
    return LootToastMoverDB
end

------------------------------------------------ Anchor box ----------------------------------------
local anchor = CreateFrame("Frame", "LootToastMoverAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
-- Toasts render at FULLSCREEN_DIALOG, so a live toast draws on top of this box rather than
-- disappearing behind it.
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
title:SetText("|cffffd100LootToastMover|r")

local body = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
body:SetPoint("CENTER", 0, -2)
body:SetText("Drag me. Toasts appear\nin this exact space.")
body:SetJustifyH("CENTER")

local hint = anchor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOM", 0, 8)
hint:SetText("/ltm test")

anchor:Hide()

------------------------------------------------ Helper to snap AlertFrame --------------------------
-- Alerts anchor their BOTTOM to AlertFrame's BOTTOM and stack upward from there (see
-- AlertContainerMixin:UpdateAnchors and GetPointsForJustification). Lining AlertFrame's bottom
-- edge up with the box's means the first toast lands exactly on the box.
local function SnapAlert()
    AlertFrame:ClearAllPoints()
    AlertFrame:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
end
AlertFrame.ignoreFramePositionManager = true
hooksecurefunc(AlertFrame, "UpdateAnchors", SnapAlert)

------------------------------------------------ Position helpers ----------------------------------
local function ApplySavedPosition()
    local db = GetDB()
    anchor:ClearAllPoints()
    if db.point then
        anchor:SetPoint(db.point, UIParent, db.relPoint or db.point, db.xOfs or 0, db.yOfs or 0)
    else
        anchor:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y)
    end
    SnapAlert()
end

local function ResetPosition()
    local db = GetDB()
    db.point, db.relPoint, db.xOfs, db.yOfs = nil, nil, nil, nil
    anchor:ClearAllPoints()
    anchor:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y)
    SnapAlert()
end

local function ToggleAnchor()
    anchor:SetShown(not anchor:IsShown())
end

------------------------------------------------ Sample toast ---------------------------------------
-- Fires a genuine loot toast through Blizzard's own alert system, so what you see is exactly
-- what a real drop looks like in the position you have chosen.
local function ShowSampleToast()
    if not LootAlertSystem then
        Say("the loot alert system is not available yet.")
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
anchor:SetScript("OnDragStart", anchor.StartMoving)
anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, xOfs, yOfs = self:GetPoint()
    local db = GetDB()
    db.point, db.relPoint, db.xOfs, db.yOfs = point, relPoint, xOfs, yOfs
    SnapAlert()
end)

------------------------------------------------ Shared tooltip text --------------------------------
-- The compartment entry, the minimap button and the broker plugin all describe the same
-- three actions, so they are written once here.
local function FillTooltip(tooltip)
    tooltip:AddLine(DISPLAY_NAME)
    tooltip:AddLine("Click to show or hide the anchor box", 1, 1, 1)
    tooltip:AddLine("Right-click for options", 1, 1, 1)
    tooltip:AddLine("/ltm test – show a sample toast", 0.6, 0.6, 0.6)
    tooltip:AddLine("/ltm reset – reset position", 0.6, 0.6, 0.6)
end

------------------------------------------------ Options panel --------------------------------------
-- Registered into Game Menu → Options → AddOns. Forward-declared because the minimap button
-- and the broker plugin both open it from their right-click handlers, and they are defined
-- first.
local OpenOptions

local optionsCategory
local refreshOptions -- set once the panel is built; syncs widgets with the saved variables

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
    blurb:SetText("Show the anchor box, drag it where you want loot toasts to appear, then "
        .. "hide it again. Toasts land in exactly that space and stack upward from it.")

    local toggleButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    toggleButton:SetSize(200, 24)
    toggleButton:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -16)
    toggleButton:SetText("Show / hide anchor box")
    toggleButton:SetScript("OnClick", ToggleAnchor)

    local testButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testButton:SetSize(200, 24)
    testButton:SetPoint("TOPLEFT", toggleButton, "BOTTOMLEFT", 0, -8)
    testButton:SetText("Show a sample toast")
    testButton:SetScript("OnClick", ShowSampleToast)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(200, 24)
    resetButton:SetPoint("TOPLEFT", testButton, "BOTTOMLEFT", 0, -8)
    resetButton:SetText("Reset position")
    resetButton:SetScript("OnClick", function()
        ResetPosition()
        Say("position reset.")
    end)

    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -16)

    -- The template's own label is a $parent-named global, which needs the checkbox to be
    -- named; creating the label here keeps both anonymous and the text under our control.
    local checkLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
    checkLabel:SetText("Show the minimap button")

    -- Assigned at the end of the file, once the minimap button exists.
    panel.setMinimapShown = nil

    check:SetScript("OnClick", function(self)
        local db = GetDB()
        db.minimapButton.hide = not self:GetChecked()
        if panel.setMinimapShown then panel.setMinimapShown(not db.minimapButton.hide) end
    end)

    local commands = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    commands:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -16)
    commands:SetJustifyH("LEFT")
    commands:SetText("/ltm or /loottoastpos – show or hide the anchor box\n"
        .. "/ltm test – show a sample loot toast\n"
        .. "/ltm reset – move the anchor back to its default position\n"
        .. "/ltm config – open this panel")

    refreshOptions = function()
        check:SetChecked(not GetDB().minimapButton.hide)
    end

    -- Blizzard's canvas layout calls these when the panel is shown, when Okay is pressed and
    -- when Defaults is pressed. Nothing is staged, so committing is a no-op.
    panel.OnRefresh = refreshOptions
    panel.OnCommit = function() end
    panel.OnDefault = function()
        ResetPosition()
        local db = GetDB()
        db.minimapButton.hide = false
        db.minimapButton.angle = DEFAULT_MINIMAP_ANGLE
        if panel.setMinimapShown then panel.setMinimapShown(true) end
        refreshOptions()
    end

    -- Settings.RegisterAddOnCategory has been the way in since 10.0, and the TOC floor is
    -- well past that; the guard is only so a stripped client cannot break the whole addon.
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

local FALLBACK_HINT = "Use /ltm, /ltm test and /ltm reset instead."

OpenOptions = function()
    if not (optionsCategory and Settings and Settings.OpenToCategory) then
        Say("the options panel is not available on this client. " .. FALLBACK_HINT)
        return
    end
    -- The id is whatever the game assigned at registration. Clients before 11.x also
    -- resolved the category name, so that is the fallback when there is no numeric id.
    local id = optionsCategory.GetID and optionsCategory:GetID() or optionsCategory.ID
    if type(id) ~= "number" then id = DISPLAY_NAME end
    -- Opening options is a convenience, never worth a Lua error popup: if Blizzard changes
    -- the call again, say so in chat and leave the slash commands working.
    if not pcall(Settings.OpenToCategory, id) then
        Say("could not open the options panel. " .. FALLBACK_HINT)
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
    self:SetScript("OnUpdate", DragMinimapButton)
end)
minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        OpenOptions()
    else
        ToggleAnchor()
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    FillTooltip(GameTooltip)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

minimapButton:Hide()

local function SetMinimapButtonShown(shown)
    minimapButton:SetShown(shown and true or false)
end
optionsPanel.setMinimapShown = SetMinimapButtonShown

local function ApplyMinimapButtonState()
    local db = GetDB()
    PlaceMinimapButton(db.minimapButton.angle)
    SetMinimapButtonShown(not db.minimapButton.hide)
end

local function ToggleMinimapButton()
    local db = GetDB()
    db.minimapButton.hide = not db.minimapButton.hide
    SetMinimapButtonShown(not db.minimapButton.hide)
    if refreshOptions then refreshOptions() end
    return not db.minimapButton.hide
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
        OnClick = function(_, button)
            if button == "RightButton" then
                OpenOptions()
            else
                ToggleAnchor()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            FillTooltip(tooltip)
        end,
    })
    brokerRegistered = true
    return true
end

------------------------------------------------ Addon Compartment ----------------------------------
-- Registered declaratively from the TOC, which is why these have to be globals. Blizzard calls
-- them as func(addonName, buttonName) and func(addonName, button); see
-- Blizzard_Minimap/Mainline/AddonCompartment.lua.

function LootToastMover_OnCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        OpenOptions()
    else
        ToggleAnchor()
    end
end

function LootToastMover_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    FillTooltip(GameTooltip)
    GameTooltip:Show()
end

function LootToastMover_OnCompartmentLeave()
    GameTooltip:Hide()
end

------------------------------------------------ Slash cmd -----------------------------------------
SLASH_LOOTTOASTPOS1 = "/loottoastpos"
SLASH_LOOTTOASTPOS2 = "/ltm"
SlashCmdList.LOOTTOASTPOS = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "reset" then
        ResetPosition()
        Say("position reset.")
    elseif cmd == "test" then
        ShowSampleToast()
    elseif cmd == "config" or cmd == "options" then
        OpenOptions()
    elseif cmd == "minimap" then
        Say("minimap button " .. (ToggleMinimapButton() and "shown." or "hidden."))
    elseif cmd == "" then
        ToggleAnchor()
    else
        Say("usage:")
        print("  |cffffd100/ltm|r – show or hide the anchor box")
        print("  |cffffd100/ltm test|r – show a sample loot toast")
        print("  |cffffd100/ltm reset|r – move the anchor back to its default position")
        print("  |cffffd100/ltm config|r – open the options panel")
        print("  |cffffd100/ltm minimap|r – show or hide the minimap button")
    end
end

------------------------------------------------ Init ----------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName ~= ADDON_NAME then return end
        ApplySavedPosition()
        ApplyMinimapButtonState()
        if refreshOptions then refreshOptions() end
        self:UnregisterEvent(event)
    elseif event == "PLAYER_LOGIN" then
        -- Every addon has loaded by now, so a broker display's copy of LibDataBroker is in
        -- place if there is one. One attempt, no retry ticker.
        RegisterBroker()
        self:UnregisterEvent(event)
    end
end)
