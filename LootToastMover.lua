
----------------------------------------------------------------------------------------------------
-- LootToastMover ▪ v4.10.0 --------------------------------------------------------------------------
-- Re-anchors Blizzard's AlertFrame (loot toasts, achievements) to a draggable anchor box.
----------------------------------------------------------------------------------------------------
local ADDON_NAME = ...

-- The exact footprint of LootWonAlertFrameTemplate, so the anchor box is the same size and
-- shape as the toast that will land on it.
local TOAST_WIDTH, TOAST_HEIGHT = 276, 96

local DEFAULT_POINT, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y = "TOP", "TOP", 0, -200

-- Hearthstone. Every character has one, so it always resolves to a valid item link.
local SAMPLE_ITEM_ID = 6948

------------------------------------------------ Saved variables -----------------------------------
local SCHEMA_VERSION = 2

-- 4.9.x and earlier used a 260x60 box with AlertFrame pinned 56px below its centre. AlertFrame
-- is 10 tall and alerts anchor BOTTOM-to-BOTTOM with it, which put the first toast's bottom
-- edge 31px *below* the box rather than on it. The box is now the toast's real footprint with
-- the toast sitting directly on it, so an existing saved position has to shift to keep toasts
-- where the user actually put them.
local LEGACY_BOX_HEIGHT, LEGACY_TOAST_GAP = 60, 31

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
    -- Left over from the LibDBIcon minimap button that the Addon Compartment replaced.
    LootToastMoverDB.minimap = nil
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
hint:SetText("/loottoastpos test")

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
        print("|cff00c0ff[LootToastMover]|r the loot alert system is not available yet.")
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

------------------------------------------------ Addon Compartment ----------------------------------
-- Registered declaratively from the TOC, which is why these have to be globals. Blizzard calls
-- them as func(addonName, buttonName) and func(addonName, button); see
-- Blizzard_Minimap/Mainline/AddonCompartment.lua.

function LootToastMover_OnCompartmentClick()
    ToggleAnchor()
end

function LootToastMover_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("LootToastMover")
    GameTooltip:AddLine("Click to show or hide the anchor box", 1, 1, 1)
    GameTooltip:AddLine("/loottoastpos test – show a sample toast", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("/loottoastpos reset – reset position", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function LootToastMover_OnCompartmentLeave()
    GameTooltip:Hide()
end

------------------------------------------------ Slash cmd -----------------------------------------
SLASH_LOOTTOASTPOS1 = "/loottoastpos"
SlashCmdList.LOOTTOASTPOS = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "reset" then
        ResetPosition()
        print("|cff00c0ff[LootToastMover]|r position reset.")
    elseif cmd == "test" then
        ShowSampleToast()
    elseif cmd == "" then
        ToggleAnchor()
    else
        print("|cff00c0ff[LootToastMover]|r usage:")
        print("  |cffffd100/loottoastpos|r – show or hide the anchor box")
        print("  |cffffd100/loottoastpos test|r – show a sample loot toast")
        print("  |cffffd100/loottoastpos reset|r – move the anchor back to its default position")
    end
end

------------------------------------------------ Init ----------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= ADDON_NAME then return end
    ApplySavedPosition()
    self:UnregisterEvent(event)
end)
