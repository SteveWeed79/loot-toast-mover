-- luacheck configuration. WoW runs Lua 5.1 and injects a large global namespace.
std = "lua51"

max_line_length = 110

exclude_files = {
    "Libs/", -- third-party, linted upstream
}

-- Globals the addon is allowed to define or write to.
globals = {
    "LootToastMoverDB",
    "SLASH_LOOTTOASTPOS1",
    "SlashCmdList",
    -- Opting AlertFrame out of Blizzard's frame position manager is the whole point of
    -- this addon, so writing this one field is expected. AlertFrame itself stays read-only.
    "AlertFrame.ignoreFramePositionManager",
}

-- WoW API surface the addon reads but never defines.
read_globals = {
    "AlertFrame",
    "C_AddOns",
    "C_Timer",
    "CreateFrame",
    "IsLoggedIn",
    "LibStub",
    "Minimap",
    "UIParent",
    "hooksecurefunc",
    "strtrim",
    "wipe",
}

-- The test harness defines stand-ins for the whole client, so it plays by looser rules.
files["tests/"] = {
    std = "lua51",
    globals = { "_G" },
    read_globals = {
        "AlertFrame", "CHAT", "C_AddOns", "C_Timer", "CreateFrame", "FireEvent",
        "IsLoggedIn", "LibStub", "LootToastMoverDB", "Minimap", "SlashCmdList",
        "TickAll", "UIParent", "UnboundedTickers", "hooksecurefunc", "strtrim", "wipe",
    },
}
