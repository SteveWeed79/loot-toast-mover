
----------------------------------------------------------------------------------------------------
-- LootToastMover ▪ v4.9.0 ---------------------------------------------------------------------------
-- Re-anchors Blizzard's AlertFrame (loot toasts, achievements) to a draggable anchor box.
----------------------------------------------------------------------------------------------------
local ADDON_NAME = ...

local DEFAULT_POINT, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y = "TOP", "TOP", 0, -200
local ALERT_Y_OFFSET = -56

------------------------------------------------ Saved variables -----------------------------------
-- Only ever called from ADDON_LOADED onwards, which is the point at which SavedVariables are
-- guaranteed to be in place.
local function GetDB()
    if type(LootToastMoverDB) ~= "table" then LootToastMoverDB = {} end
    -- Left over from the LibDBIcon minimap button that the Addon Compartment replaced. Dropped
    -- here so it does not linger in the saved variables file forever.
    LootToastMoverDB.minimap = nil
    return LootToastMoverDB
end

------------------------------------------------ Anchor box ----------------------------------------
local anchor = CreateFrame("Frame", "LootToastMoverAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(260, 60)
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetFrameStrata("HIGH")

anchor:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false, edgeSize = 12,
    insets   = {left = 3, right = 3, top = 3, bottom = 3},
})
anchor:SetBackdropColor(0, 0, 0, 0.85)
anchor:SetBackdropBorderColor(1, 1, 1, 1)

local fs = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
fs:SetPoint("CENTER")
fs:SetText("|cffffd100LTM|r  |cffffffffMove Me|r")

anchor:Hide()

------------------------------------------------ Helper to snap AlertFrame --------------------------
local function SnapAlert()
    AlertFrame:ClearAllPoints()
    AlertFrame:SetPoint("CENTER", anchor, "CENTER", 0, ALERT_Y_OFFSET)
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

------------------------------------------------ Drag handling -------------------------------------
anchor:SetScript("OnDragStart", anchor.StartMoving)
anchor:SetScript("OnDragStop", function(self)
    AlertFrame:ClearAllPoints()         -- break existing link
    self:StopMovingOrSizing()
    local point, _, relPoint, xOfs, yOfs = self:GetPoint()
    local db = GetDB()
    db.point, db.relPoint, db.xOfs, db.yOfs = point, relPoint, xOfs, yOfs
    SnapAlert()
end)

------------------------------------------------ Addon Compartment ----------------------------------
-- Registered declaratively from the TOC, which is why these have to be globals. Blizzard calls
-- them as func(addonName, buttonName) and func(addonName, button); see
-- Blizzard_Minimap/Mainline/AddonCompartment.lua. This replaces the LibDataBroker launcher and
-- LibDBIcon minimap button the addon used to carry four libraries for.

function LootToastMover_OnCompartmentClick()
    ToggleAnchor()
end

function LootToastMover_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("LootToastMover")
    GameTooltip:AddLine("Click to show or hide the anchor box", 1, 1, 1)
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
    elseif cmd == "" then
        ToggleAnchor()
    else
        print("|cff00c0ff[LootToastMover]|r usage:")
        print("  |cffffd100/loottoastpos|r – show or hide the anchor box")
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
