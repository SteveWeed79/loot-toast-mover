-- luacheck configuration. WoW runs Lua 5.1 and injects a large global namespace.
std = "lua51"

max_line_length = 110

-- Globals the addon is allowed to define or write to.
globals = {
    "LootToastMoverDB",
    "SLASH_LOOTTOASTPOS1",
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
    "Item",            -- ItemMixin factory, for loading the sample item
    "LootAlertSystem", -- Blizzard's loot toast subsystem
    "UIParent",
    "hooksecurefunc",
    "strtrim",
}

-- The test harness defines stand-ins for the whole client, so it plays by looser rules.
files["tests/"] = {
    std = "lua51",
    globals = { "_G" },
    read_globals = {
        "AlertFrame", "CHAT", "CreateFrame", "FireEvent", "FlushItemLoads", "GameTooltip",
        "Item", "LootAlertSystem", "LootToastMoverDB", "LootToastMover_OnCompartmentClick",
        "LootToastMover_OnCompartmentEnter", "LootToastMover_OnCompartmentLeave",
        "PENDING_ITEM_LOADS", "SlashCmdList", "TickAll", "UIParent", "UnboundedTickers",
        "hooksecurefunc", "strtrim",
    },
}
