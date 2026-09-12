-- Minimal emulation of the World of Warcraft API, enough to execute LootToastMover
-- outside the game. Widget methods that the addon does not depend on are no-ops.
--
-- This is deliberately small: it models only what the addon actually touches.

local M = {}

local noop = function() end

-- reset() replaces the global print so the addon's chat output can be asserted on.
-- Test code must write to stdout through this instead.
M.stdout = print

----------------------------------------------------------------------- Frames ----------
local Frame = {}
Frame.__index = function(_, k)
    local v = rawget(Frame, k)
    if v ~= nil then return v end
    -- Underscore keys are this stub's own bookkeeping and must read as nil when unset.
    if type(k) == "string" and k:sub(1, 1) == "_" then return nil end
    return noop -- unmodelled widget method
end

function Frame:SetPoint(p, rel, rp, x, y)
    -- Both SetPoint("CENTER") and SetPoint("CENTER", rel, "CENTER", x, y) are legal.
    if type(rel) == "string" then p, rel, rp, x, y = p, nil, rel, rp, x end
    self._point = { p, rel, rp or p, x or 0, y or 0 }
end
function Frame:GetPoint()
    local pt = self._point
    if not pt then return nil end
    return pt[1], pt[2], pt[3], pt[4], pt[5]
end
function Frame:ClearAllPoints() self._point = nil end
function Frame:SetShown(s) self._shown = s and true or false end
function Frame:IsShown() return self._shown and true or false end
function Frame:Show() self._shown = true end
function Frame:Hide() self._shown = false end
function Frame:SetScript(k, fn) self._scripts = self._scripts or {}; self._scripts[k] = fn end
function Frame:GetScript(k) return self._scripts and self._scripts[k] end
function Frame:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
function Frame:UnregisterEvent(e) if self._events then self._events[e] = nil end end
function Frame:IsEventRegistered(e) return (self._events and self._events[e]) and true or false end
function Frame:StartMoving() self._moving = true end
function Frame:StopMovingOrSizing() self._moving = false end
-- Assigned rather than declared with `:` so the unused self argument stays implicit.
Frame.CreateFontString = function() return setmetatable({}, Frame) end

--- Reset every global this stub owns, so each test starts from a clean client.
function M.reset()
    local frames = {}

    _G.CreateFrame = function(_, name)
        local f = setmetatable({ _name = name }, Frame)
        if name then _G[name] = f end
        table.insert(frames, f)
        return f
    end

    --- Dispatch an event to every frame registered for it.
    _G.FireEvent = function(event, ...)
        for _, f in ipairs(frames) do
            if f._events and f._events[event] and f._scripts and f._scripts.OnEvent then
                f._scripts.OnEvent(f, event, ...)
            end
        end
    end

    _G.UIParent   = setmetatable({ _name = "UIParent" }, Frame)
    _G.AlertFrame = setmetatable({ _name = "AlertFrame" }, Frame)
    function _G.AlertFrame:UpdateAnchors()
        self._updateAnchorsCalls = (self._updateAnchorsCalls or 0) + 1
    end

    -- GameTooltip, as much of it as the Addon Compartment tooltip uses. Lines are captured
    -- so tests can assert on what the tooltip actually says.
    _G.GameTooltip = setmetatable({ _name = "GameTooltip", lines = {} }, Frame)
    function _G.GameTooltip:SetOwner(owner) self.owner = owner; self.lines = {} end
    function _G.GameTooltip:AddLine(text) table.insert(self.lines, text) end
    function _G.GameTooltip:Show() self._shown = true end
    function _G.GameTooltip:Hide() self._shown = false end

    _G.hooksecurefunc = function(tbl, name, post)
        if type(tbl) == "string" then tbl, name, post = _G, tbl, name end
        local orig = tbl[name]
        tbl[name] = function(...)
            local r = { orig(...) }
            post(...)
            return unpack(r)
        end
    end

    -- Midnight-era client: the AddOn query functions live in C_AddOns and the old bare
    -- globals are gone. Leaving IsAddOnLoaded undefined is deliberate.
    _G.loadedAddOns = {}
    _G.C_AddOns = { IsAddOnLoaded = function(n) return _G.loadedAddOns[n] or false end }
    _G.IsAddOnLoaded = nil

    _G.C_Timer = { _tickers = {} }
    _G.C_Timer.NewTicker = function(_, fn, iters)
        local t = { fn = fn, iters = iters, fired = 0, cancelled = false }
        t.Cancel = function(self) self.cancelled = true end
        table.insert(_G.C_Timer._tickers, t)
        return t
    end
    _G.TickAll = function(n)
        for _ = 1, (n or 1) do
            for _, t in ipairs(_G.C_Timer._tickers) do
                if not t.cancelled and (not t.iters or t.fired < t.iters) then
                    t.fired = t.fired + 1
                    t.fn()
                end
            end
        end
    end
    --- Tickers still firing with no iteration cap, i.e. leaked for the whole session.
    _G.UnboundedTickers = function()
        local n = 0
        for _, t in ipairs(_G.C_Timer._tickers) do
            if not t.cancelled and not t.iters then n = n + 1 end
        end
        return n
    end

    _G.IsLoggedIn = function() return true end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.SlashCmdList = {}
    _G.LootToastMoverDB = nil
    _G.LootToastMover_OnCompartmentClick = nil
    _G.LootToastMover_OnCompartmentEnter = nil
    _G.LootToastMover_OnCompartmentLeave = nil

    -- WoW also exposes the Lua string/table/math libraries as bare globals.
    _G.strmatch, _G.strfind, _G.strsub = string.match, string.find, string.sub
    _G.strupper, _G.strlower, _G.strrep = string.upper, string.lower, string.rep
    _G.strbyte, _G.strchar, _G.format = string.byte, string.char, string.format
    _G.gsub, _G.gmatch = string.gsub, string.gmatch
    _G.tinsert, _G.tremove, _G.sort = table.insert, table.remove, table.sort
    _G.max, _G.min, _G.abs = math.max, math.min, math.abs
    _G.floor, _G.ceil, _G.sqrt = math.floor, math.ceil, math.sqrt
    _G.strtrim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
    _G.strjoin = function(sep, ...) return table.concat({ ... }, sep) end

    -- Capture chat output so tests can assert on it.
    _G.CHAT = {}
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        table.insert(_G.CHAT, table.concat(parts, " "))
    end
end

return M
