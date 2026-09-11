
----------------------------------------------------------------------------------------------------
-- LootToastMover ▪ v4.8.4 ---------------------------------------------------------------------------
-- Re-anchors Blizzard's AlertFrame (loot toasts, achievements) to a draggable anchor box.
----------------------------------------------------------------------------------------------------
local ADDON_NAME = ...

-- The bare AddOn query globals moved into C_AddOns in 10.2.0 and stopped working reliably in
-- 11.0.2. Resolve once, keeping the old global as a fallback for older Classic clients.
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded

local DEFAULT_POINT, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y = "TOP", "TOP", 0, -200
local ALERT_Y_OFFSET = -56

------------------------------------------------ Saved variables -----------------------------------
-- Only ever called from ADDON_LOADED onwards, which is the point at which SavedVariables are
-- guaranteed to be in place.
local function GetDB()
    if type(LootToastMoverDB) ~= "table" then LootToastMoverDB = {} end
    -- LibDBIcon owns this sub-table; it stores the minimap button's angle and hidden state.
    if type(LootToastMoverDB.minimap) ~= "table" then LootToastMoverDB.minimap = {} end
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
    -- Clear only the anchor keys; db.minimap belongs to LibDBIcon and must survive a reset.
    db.point, db.relPoint, db.xOfs, db.yOfs = nil, nil, nil, nil
    anchor:ClearAllPoints()
    anchor:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y)
    SnapAlert()
end

------------------------------------------------ Drag handling -------------------------------------
anchor:SetScript("OnDragStart", anchor.StartMoving)
anchor:SetScript("OnDragStop", function(self)
    AlertFrame:ClearAllPoints()         -- break existing link
    self:StopMovingOrSizing()
    local point, _, relPoint, xOfs, yOfs = self:GetPoint()
    -- Assign field by field: replacing the table would discard db.minimap.
    local db = GetDB()
    db.point, db.relPoint, db.xOfs, db.yOfs = point, relPoint, xOfs, yOfs
    SnapAlert()
end)

------------------------------------------------ Broker ---------------------------------------------
local dataobj
local DBIcon

local function CreateBroker()
    if dataobj then return end
    local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not LDB then return end
    dataobj = LDB:NewDataObject("LootToastMover", {
        type = "data source",
        icon = "Interface\\Icons\\inv_misc_bag_10",
        text = "LTM",
        OnClick = function() anchor:SetShown(not anchor:IsShown()) end,
        OnTooltipShow = function(tt)
            tt:AddLine("LootToastMover")
            tt:AddLine("Click to show/hide anchor", 1, 1, 1)
            tt:AddLine("/loottoastpos reset – reset position", 0.6, 0.6, 0.6)
        end,
    })
end

local function RegisterMinimapIcon()
    if not dataobj then return end
    DBIcon = DBIcon or (LibStub and LibStub("LibDBIcon-1.0", true))
    if not DBIcon then return end
    -- LibDBIcon raises a hard error when the same name is registered twice.
    if DBIcon:GetMinimapButton("LootToastMover") then return end
    -- A broker display already surfaces the data object, so skip the extra minimap button.
    if IsAddOnLoaded and (IsAddOnLoaded("Titan") or IsAddOnLoaded("ChocolateBar")) then return end
    -- The third argument has to be a persisted table: LibDBIcon writes the button's dragged
    -- position into db.minimapPos and reads db.hide/db.lock back out of it.
    DBIcon:Register("LootToastMover", dataobj, GetDB().minimap)
end

------------------------------------------------ Slash cmd -----------------------------------------
SLASH_LOOTTOASTPOS1 = "/loottoastpos"
SlashCmdList.LOOTTOASTPOS = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "reset" then
        ResetPosition()
        print("|cff00c0ff[LootToastMover]|r position reset.")
    elseif cmd == "" then
        anchor:SetShown(not anchor:IsShown())
    else
        print("|cff00c0ff[LootToastMover]|r usage:")
        print("  |cffffd100/loottoastpos|r – show or hide the anchor box")
        print("  |cffffd100/loottoastpos reset|r – move the anchor back to its default position")
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
        if IsLoggedIn() then
            -- Loaded after login, so PLAYER_LOGIN will not fire again.
            CreateBroker()
            RegisterMinimapIcon()
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        CreateBroker()
        RegisterMinimapIcon()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
