-- The games LootToastMover is built for, and how to tell their Interface numbers apart.
--
-- One TOC serves every game by listing an Interface number for each. tests/check_toc.lua
-- uses this list to insist that every game is there and nothing else is, and
-- tools/bump_version.lua uses it to name the games in a changelog entry.
--
-- The patterns follow the BigWigs packager's toc_to_type, because that is what decides
-- which CurseForge game version each number is uploaded under. A number that matches none
-- of them would be tagged as retail there, so it has to fail the check here instead.
--
-- The order is the one the release workflow asks toc-interface-updater for, which is the
-- order it writes the numbers back in.

local M = {}

M.list = {
    -- Six digits since 10.0. Patch 12.0 raised the floor for mainline addons to 120000.
    -- Sources disagree on whether a lower number is merely flagged out of date or refused
    -- outright, but either way an addon below it does not load for a normal user.
    { name = "Retail", pattern = "^%d%d%d%d%d%d$", floor = 120000 },
    -- World of Warcraft: Forever, which runs the retail client and UI. 1.60.1 is 16001.
    { name = "Forever", pattern = "^16%d%d%d$" },
    { name = "Mists of Pandaria Classic", pattern = "^50%d%d%d$" },
    -- China only, and a Wrath of the Lich King client: 3.80.2 is 38002.
    { name = "Titan Reforged Classic", pattern = "^380%d%d$" },
    -- The Anniversary realms, now on The Burning Crusade: 2.5.6 is 20506.
    { name = "TBC Anniversary", pattern = "^20%d%d%d$" },
    { name = "Classic Era", pattern = "^11%d%d%d$" },
}

--- The game an Interface number belongs to, or nil when it is none of them.
function M.of(interface)
    local digits = tostring(interface)
    for _, game in ipairs(M.list) do
        if digits:find(game.pattern) then return game end
    end
end

--- "120105" -> "12.1.5", "11509" -> "1.15.9". The last two digits are the patch, the two
--- before that the minor, and whatever remains the major.
function M.version(interface)
    local digits = tostring(interface)
    local patch = tonumber(digits:sub(-2))
    local minor = tonumber(digits:sub(-4, -3))
    local major = tonumber(digits:sub(1, -5))
    if not (major and minor and patch) then return nil end
    return ("%d.%d.%d"):format(major, minor, patch)
end

return M
