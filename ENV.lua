-- lib.lua

local AANAME, AAENV = ...

AAENV.CLOG_EVENTS_AURA_APPLIED = {
  SPELL_AURA_APPLIED = true,
  SPELL_AURA_APPLIED_DOSE = true,
  SPELL_AURA_REFRESH = true,
}
AAENV.CLOG_EVENTS_AURA_REMOVED = {
  SPELL_AURA_REMOVED = true,
  SPELL_AURA_REMOVED_DOSE = true,
  -- SPELL_AURA_BROKEN = true,
  -- SPELL_AURA_BROKEN_SPELL = true,
}

AAENV.config = {
  auraSize = 28,
  auraMargin = 4,
}

AAENV.lib = {}

AAENV.lib.GetGcdInfo = function()
  local start, duration = GetSpellCooldown(61304)
  return {
    start = start,
    duration = duration,
    finish = start + duration
  }
end

AAENV.lib.GetSpellCooldownAndCharges = function(id, gcdInfo)
  -- taken and modified from WeakAuras2 (WeakAuras.GetSpellCooldownUnified)
  local charges, maxCharges, start, duration, modRate = GetSpellCharges(id);
  if (charges == nil) then -- spell does not work with charges
    local basecd = GetSpellBaseCooldown(id);
    local enabled;
    start, duration, enabled, modRate = GetSpellCooldown(id);
    if (enabled == 0) then
      start, duration = 0, 0
    end

    -- GetSpellCount returns 0 for all spells that have no spell counts, so we only use that information if
    -- either the spell count is greater than 0 or we have a ability without a base cooldown
    -- Checking the base cooldown is not enough though, since some abilities have no base cooldown, but can still be on cooldown
    -- e.g. Raging Blow that gains a cooldown with a talent(???)
    local spellcount = GetSpellCount(id);
    if (spellcount > 0) then
      charges = spellcount;
    end

    local onNonGCDCD = duration and startTime and duration > 0 and (duration ~= gcdDuration or startTime ~= gcdStart);

    local matchesGCD = duration == nil or duration == 0 or start == nil or (duration == gcdInfo.duration and start == gcdInfo.start);
    if basecd == nil or basecd == 0 or matchesGCD then
      charges = spellcount;
      start = 0;
      duration = 0;
    end
  elseif (charges == maxCharges) then
    start, duration = 0, 0;
  elseif (charges == 0 and duration == 0) then -- Lavaburst+Ascendance has 0 charges, but the spell is useable
    charges = 1;
  end

  start = start or 0;
  duration = duration or 0;
  -- WORKAROUND Very rarely the API returns very high bogus numbers causing client freeezes, discard them.
  -- WowAce WeakAuras2 issue #1008: https://www.wowace.com/projects/weakauras-2/issues/1008
  if (duration > 604800) then
    duration = 0;
    start = 0;
  end

  return start, duration, charges, maxCharges, modRate;
end

AAENV.lib.FindBuffByID = function(unit, id)
  for i=1,40 do
    local auraInfo = {UnitBuff(unit, i)}
    if auraInfo[10] == id then
      return unpack(auraInfo)
    end
  end
end

AAENV.lib.FindDebuffByID = function(unit, id)
  for i=1,40 do
    local auraInfo = {UnitDebuff(unit, i)}
    if auraInfo[10] == id then
      return unpack(auraInfo)
    end
  end
end

AAENV.lib.FindAuraByID = function(unit, id)
  local res = {AAENV.lib.FindBuffByID(unit, id)}
  if #res == 0 then
    res = {AAENV.lib.FindDebuffByID(unit, id)}
  end
  return unpack(res)
end

-- Compatible with Lua 5.1 (not 5.0).
-- Provides a class function to facilitate oop
AAENV.lib.class = function(base, init)
  local c = {}    -- a new class instance
  if not init and type(base) == 'function' then
    init = base
    base = nil
  elseif type(base) == 'table' then
  -- our new class is a shallow copy of the base class!
    for i,v in pairs(base) do
      c[i] = v
    end
    c._base = base
  end
  -- the class will be the metatable for all its objects,
  -- and they will look up their methods in it.
  c.__index = c

  -- expose a constructor which can be called by <classname>(<args>)
  local mt = {}
  mt.__call = function(class_tbl, ...)
    local obj = {}
    setmetatable(obj,c)
    if init then
      init(obj,...)
    else
      -- make sure that any stuff from the base class is initialized!
      if base and base.init then
        base.init(obj, ...)
      end
    end
    return obj
  end
  c.init = init
  c.is_a = function(self, klass)
     local m = getmetatable(self)
     while m do
        if m == klass then return true end
        m = m._base
     end
     return false
  end
  setmetatable(c, mt)
  return c
end
