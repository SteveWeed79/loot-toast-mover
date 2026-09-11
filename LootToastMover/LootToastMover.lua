
----------------------------------------------------------------------------------------------------
-- LootToastMover ▪ v4.7.1 – fixed circular anchoring error ----------------------------------------
----------------------------------------------------------------------------------------------------
local ADDON = ...

LootToastMoverDB = LootToastMoverDB or {}

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
    AlertFrame:SetPoint("CENTER", anchor, "CENTER", 0, -56)
end
AlertFrame.ignoreFramePositionManager = true
hooksecurefunc(AlertFrame, "UpdateAnchors", SnapAlert)

------------------------------------------------ Drag handling -------------------------------------
anchor:SetScript("OnDragStart", anchor.StartMoving)
anchor:SetScript("OnDragStop", function(self)
    AlertFrame:ClearAllPoints()         -- break existing link
    self:StopMovingOrSizing()
    local p,_,rp,x,y = self:GetPoint()
    LootToastMoverDB = {point=p, relPoint=rp, xOfs=x, yOfs=y}
    SnapAlert()
end)

------------------------------------------------ Broker ---------------------------------------------
local dataobj
local DBIcon = LibStub("LibDBIcon-1.0", true)

local function createBroker()
    if dataobj then return end
    local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not LDB then return end
    dataobj = LDB:NewDataObject("LootToastMover", {
        -- fallback minimap icon if no broker bar is present
        minimap = { hide = false },
        type="data source",
        icon="Interface\\Icons\\inv_misc_bag_10",
        text="LTM",
        OnClick=function() anchor:SetShown(not anchor:IsShown()) end,
        OnTooltipShow=function(tt)
            tt:AddLine("LootToastMover")
            tt:AddLine("Click to show/hide anchor",1,1,1)
            tt:AddLine("/loottoastpos reset – reset position",0.6,0.6,0.6)
        end,
    })
end
C_Timer.NewTicker(1, createBroker)

------------------------------------------------ Slash cmd -----------------------------------------
SLASH_LOOTTOASTPOS1 = "/loottoastpos"
SlashCmdList.LOOTTOASTPOS = function(msg)
    if msg:lower() == "reset" then
        wipe(LootToastMoverDB)
        AlertFrame:ClearAllPoints()
        anchor:ClearAllPoints()
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -200)
        SnapAlert()
        print("|cff00c0ff[LootToastMover]|r position reset.")
    else
        anchor:SetShown(not anchor:IsShown())
            if DBIcon and not IsAddOnLoaded("Titan") and not IsAddOnLoaded("ChocolateBar") then
            DBIcon:Register("LootToastMover", dataobj, {})
        end
    end
end

------------------------------------------------ Init ----------------------------------------------
local function init()
    local db = LootToastMoverDB
    anchor:ClearAllPoints()
    if db and db.point then
        anchor:SetPoint(db.point, UIParent, db.relPoint, db.xOfs, db.yOfs)
    else
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
    SnapAlert()
    createBroker()
end
if IsLoggedIn() then init() else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", init)
end