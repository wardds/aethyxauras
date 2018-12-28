-- Addon's main entry point.

-- TODO(aethyx): figure out good frame stratas for the groups
-- TODO(aethyx): Single class/spec spell list (disc priest?)
-- TODO(aethyx): Aura positioning
-- TODO(aethyx): Buff active glow effect
-- TODO(aethyx): Aura visibility for spec/talents
-- TODO(aethyx): Aura visibility for "show when ready"
-- TODO(aethyx): Buff stack count (and dose application/removal!)
-- TODO(aethyx): Cooldown charge count
-- TODO(aethyx): More classes spell lists
-- TODO(aethyx): User configuration
-- TODO(aethyx): Optimization ideas:
--  --Have handlers return true if they've handled something, so callHandlers can break the loop
--    this would however break if multiple auras need to handle the same buff/spell/...
--  --Avoid OnUpdate handler by setting timers to return unset desaturation on icon?
--    the SPELL_UPDATE_COOLDOWN event seems to handle changes in cooldowns just fine, and triggers
--    quite often, so the swipe is always correct, just need to know when the cd finishes

-- PROGRAMMED ON PLANE:
-- Check if the positioning of the groups is fine
-- Position config/logic:
--  totalWidth = (#auras * (size + margin) ) - margin
--  startPos = totalWidth / -2 (if anchors are left)
--  endPos = totalWidth - size (if anchors are left)
-- Check sizing and overflowing rules for (main)group(s) and auras

local AANAME, AAENV = ...
local lib = AAENV.lib

-- ezpz reload ui button for testing.
local rlui = CreateFrame("BUTTON", nil, UIParent, nil, nil)
rlui:SetFrameStrata("BACKGROUND")
rlui:SetPoint("RIGHT", -100, 40)
rlui:SetWidth(40)
rlui:SetHeight(40)
rlui:Enable()
rlui:Show()
rlui:SetScript("OnClick", function() ReloadUI() end)

-- main frame, containing auras and event registrations
local mainFrame = CreateFrame("FRAME", nil, UIParent, nil, nil)
mainFrame:SetFrameStrata("BACKGROUND")
mainFrame:SetPoint("BOTTOM", 0, -100)
-- size 2 because you can't center a single pixel on a screen?
mainFrame:SetWidth(2)
mainFrame:SetHeight(2)

-- Each group is 1 horizontal "bar" of auras
local groups = {
  -- top bar
  {
    frame = CreateFrame("FRAME", nil, mainFrame, nil, nil),
    auras = {}
  },
  -- bottom bar
  {
    frame = CreateFrame("FRAME", nil, mainFrame, nil, nil),
    auras = {}
  }
}
-- top bar
groups[1].frame:SetPoint("BOTTOM", 0, 1) -- 1 pixel up from the main frame, growing upwards
groups[1].frame:SetWidth(2)
groups[1].frame:SetHeight(2)
-- bottom bar
groups[2].frame:SetPoint("TOP", 0, -1) -- 1 pixel down from the main frame, growing downwards
groups[2].frame:SetWidth(2)
groups[2].frame:SetHeight(2)


local spellConfigs = {
  { spellName = "Power Word: Radiance", group = 1 }
  { spellName = "Penance", group = 1 },

  { spellName = "Fade", buffName = "Fade", group = 2 }
  { spellName = "Rapture", buffName = "Rapture", group = 2 },
  { spellName = "Leap of Faith", group = 2 },
  { spellName = "Pain Suppression", group = 2 },
  { spellName = "Psychic Scream", group = 2 },
  { spellName = "Power Word: Barrier", group = 2 }
}

local auras = {}
local PLAYER_GUID = ""
local function createAuras()
  PLAYER_GUID = UnitGUID("player")
  for i, spellConfig in ipairs(spellConfigs) do
    local aura = AAura(#groups[spellConfig.group].auras + 1, spellConfig.spellName, spellConfig.buffName)
    groups[spellConfig.group].auras.push(aura)
    auras[i] = aura
  end
  -- TODO(aethyx): center auras/groups here?

  rlui.texture = rlui:CreateTexture(nil, "BACKGROUND")
  rlui.texture:SetAllPoints(rlui)
  rlui.texture:SetTexture(select(3, GetSpellInfo("Auto Attack")))
end

-- Calls `func` on all AAuras with given parameters
local function callHandlers(func, ...)
  for i, aura in ipairs(auras) do
    if aura[func] then
      aura[func](aura, ...)
    end
  end
end

-- Updates all auras' cooldowns
local function updateCooldowns()
  callHandlers("UpdateCooldown", lib.GetGcdEnd())
end

-- Handles the OnUpdate event, doing regular updates
local throttleUpdateCooldowns = 0.25
local sinceUpdateCooldowns = 0
local function updateHandler(self, elapsed)
  -- Update all cooldowns as required.
  -- This is really just because of the desaturation effect
  sinceUpdateCooldowns = sinceUpdateCooldowns + elapsed
  if (sinceUpdateCooldowns >= throttleUpdateCooldowns) then
    sinceUpdateCooldowns = 0
    updateCooldowns()
  end
end

local function eventHandler(self, event, ...)
  -- if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
  --   print(event)
  -- end
  if event == "SPELL_UPDATE_COOLDOWN" then
    updateCooldowns() -- no extra parameters
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local arg = {CombatLogGetCurrentEventInfo()}
    if AAENV.CLOG_EVENTS_AURA_APPLIED[arg[2]] then -- aura applied
      if (arg[4] == PLAYER_GUID and arg[4] == arg[8]) then -- self-applied
        local buffArgs = {lib.FindAuraByID("player", arg[12])}
        if #buffArgs > 0 then
          callHandlers("BuffApplied", unpack(buffArgs))
        end
      end
    elseif AAENV.CLOG_EVENTS_AURA_REMOVED[arg[2]] then -- aura removed
      if (arg[4] == PLAYER_GUID and arg[4] == arg[8]) then -- self-removed(?)
        callHandlers("BuffRemoved", arg[12])
      end
    end
  elseif (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN") and #auras == 0 then
    createAuras()
  end
end

rlui:SetScript("OnUpdate", updateHandler);
rlui:SetScript("OnEvent", eventHandler);
rlui:RegisterEvent("SPELL_UPDATE_COOLDOWN");
rlui:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
rlui:RegisterEvent("PLAYER_ENTERING_WORLD");
rlui:RegisterEvent("PLAYER_LOGIN");

