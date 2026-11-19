-- luacheck configuration. WoW runs Lua 5.1 and injects a large global namespace.
std = "lua51"

max_line_length = 110

-- Globals the addon is allowed to define or write to.
globals = {
    "LootToastMoverDB",
    "SLASH_LOOTTOASTPOS1",
    "SLASH_LOOTTOASTPOS2",
    "SlashCmdList",
    -- Registered from the TOC's AddonCompartment fields, so these must be globals.
    "LootToastMover_OnCompartmentClick",
    "LootToastMover_OnCompartmentEnter",
    "LootToastMover_OnCompartmentLeave",
    -- The one field this addon writes on AlertFrame, a flag Blizzard's managed-frame
    -- containers skip a frame for. AlertFrame itself stays read-only.
    "AlertFrame.ignoreFramePositionManager",
}

-- WoW API surface the addon reads but never defines.
read_globals = {
    "AddonCompartmentFrame",       -- only looked at to see whether this game has one
    "AlertFrame",
    "AlertFrameAutoAnchoredMixin", -- to recognise the alert frames that place themselves
    "CreateFrame",
    "EventRegistry",               -- Edit Mode's enter and exit events
    "GameTooltip",
    "GetCursorPosition",
    "GetLocale",       -- the client's text language, which picks the translation
    "Item",            -- ItemMixin factory, for loading the sample item
    "LibStub",         -- only ever looked up, never bundled; see the broker section
    "LootAlertSystem", -- Blizzard's loot toast subsystem
    "Minimap",
    "Settings",        -- the 10.0+ options system, for the AddOns panel
    "UIParent",
    "UISpecialFrames", -- frames Escape hides; the anchor box's name is added to it
    "geterrorhandler",
    "hooksecurefunc",
    "strtrim",
}

-- Each translated sentence stays on one line, so a translator sees the whole thing at once
-- rather than reassembling it from concatenated pieces.
files["Locales.lua"] = {
    max_line_length = false,
    -- Each `do local L = …` block receives CurseForge's translations only when the packager
    -- fills it in. In the repository the L there is unused by design.
    ignore = { "211/L" },
}

-- The test harness defines stand-ins for the whole client, so it plays by looser rules.
files["tests/"] = {
    std = "lua51",
    -- Settings is writable here so a test can break OpenToCategory on purpose and prove the
    -- addon survives Blizzard changing it.
    -- The other three are writable for the same reason: a test breaks one method on purpose
    -- to prove an error inside the addon is contained.
    globals = { "_G", "Settings", "AlertFrame", "GameTooltip", "LootAlertSystem" },
    read_globals = {
        "AddAlertAnchorFrame", "AddAlertQueue", "ERRORS", "EventRegistry", "PressEscape",
        "LootToastMoverOptionsPanel",
        "CHAT", "CreateFrame", "FireEvent", "FlushItemLoads",
        "GetCursorPosition", "Item", "LibStub", "LootToastMoverDB",
        "LootToastMover_OnCompartmentClick", "LootToastMover_OnCompartmentEnter",
        "LootToastMover_OnCompartmentLeave", "InstallBrokerLibs", "LootToastMoverMinimapButton",
        "Minimap", "MoveCursorTo", "PENDING_ITEM_LOADS", "SlashCmdList", "TickAll",
        "UIParent", "UnboundedTickers", "hooksecurefunc", "strtrim",
    },
}
