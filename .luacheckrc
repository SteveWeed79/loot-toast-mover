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
    -- Opting AlertFrame out of Blizzard's frame position manager is the whole point of
    -- this addon, so writing this one field is expected. AlertFrame itself stays read-only.
    "AlertFrame.ignoreFramePositionManager",
}

-- WoW API surface the addon reads but never defines.
read_globals = {
    "AlertFrame",
    "CreateFrame",
    "GameTooltip",
    "GetCursorPosition",
    "Item",            -- ItemMixin factory, for loading the sample item
    "LibStub",         -- only ever looked up, never bundled; see the broker section
    "LootAlertSystem", -- Blizzard's loot toast subsystem
    "Minimap",
    "Settings",        -- the 10.0+ options system, for the AddOns panel
    "UIParent",
    "hooksecurefunc",
    "strtrim",
}

-- The test harness defines stand-ins for the whole client, so it plays by looser rules.
files["tests/"] = {
    std = "lua51",
    -- Settings is writable here so a test can break OpenToCategory on purpose and prove the
    -- addon survives Blizzard changing it.
    globals = { "_G", "Settings" },
    read_globals = {
        "AlertFrame", "CHAT", "CreateFrame", "FireEvent", "FlushItemLoads", "GameTooltip",
        "GetCursorPosition", "Item", "LibStub", "LootAlertSystem", "LootToastMoverDB",
        "LootToastMover_OnCompartmentClick", "LootToastMover_OnCompartmentEnter",
        "LootToastMover_OnCompartmentLeave", "InstallBrokerLibs", "LootToastMoverMinimapButton",
        "Minimap", "MoveCursorTo", "PENDING_ITEM_LOADS", "SlashCmdList", "TickAll",
        "UIParent", "UnboundedTickers", "hooksecurefunc", "strtrim",
    },
}
