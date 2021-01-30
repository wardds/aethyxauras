-- Addon's main entry point.

-- TODO(aethyx): figure out good frame stratas for the groups
-- TODO(aethyx): Aura positioning
-- TODO(aethyx): Buff active glow effect
-- TODO(aethyx): Aura visibility for spec/talents
-- TODO(aethyx): Aura visibility for "show when ready"
-- TODO(aethyx): Buff stack count (and dose application/removal!)
-- TODO(aethyx): Cooldown charge count
-- TODO(aethyx): get cooldown/buff information on login/reload
-- TODO(aethyx): Buff active without duration path
-- TODO(aethyx): More classes spell lists
-- TODO(aethyx): User configuration
-- TODO(aethyx): Optimization ideas:
--  --Have handlers return true if they've handled something, so callHandlers can break the loop
--    this would however break if multiple auras need to handle the same buff/spell/...
--  --Avoid OnUpdate handler by setting timers to unset desaturation on icon?
--    the SPELL_UPDATE_COOLDOWN event seems to handle changes in cooldowns just fine, and triggers
--    quite often, so the swipe is always correct, just need to know when the cd finishes

-- Position config/logic:
--  totalWidth = (#auras * (size + margin) ) - margin
--  startPos = totalWidth / -2 (if anchors are left)
--  endPos = totalWidth - size (if anchors are left)
-- Check sizing and overflowing rules for (main)group(s) and auras

local AANAME, AAENV = ...
local lib = AAENV.lib
local config = AAENV.config

-- ezpz reload ui button for testing.
local rlui = CreateFrame("BUTTON", nil, UIParent, nil, nil)
rlui:SetFrameStrata("BACKGROUND")
rlui:SetPoint("BOTTOM", -350, 0)
rlui:SetWidth(40)
rlui:SetHeight(40)
rlui:Enable()
rlui:Show()
rlui:SetScript("OnClick", function() ReloadUI() end)

-- main frame, containing auras and event registrations
local mainFrame = CreateFrame("FRAME", nil, UIParent, nil, nil)
mainFrame:SetFrameStrata("LOW")
-- size 2 because you can't center a single pixel on a screen?
mainFrame:SetSize(5, 5)
mainFrame:SetPoint("BOTTOM", 0, 240)
mainFrame.texture = mainFrame:CreateTexture(nil, "BACKGROUND")
mainFrame.texture:SetAllPoints(true)
mainFrame.texture:SetTexture(1, 0, 0, 1)
mainFrame.texture:SetColorTexture(1, 0, 0, 1)

-- Each group is 1 horizontal "bar" of auras
local groups = {
  {
    frame = CreateFrame("FRAME", nil, mainFrame, nil, nil),
    auras = {}
  },
  {
    frame = CreateFrame("FRAME", nil, mainFrame, nil, nil),
    auras = {}
  }
}

local function GetShownAurasOfGroup(group)
  local shownAuras = {}
  for i, aura in ipairs(group.auras) do
    if aura:IsShown() then
      table.insert(shownAuras, aura)
    end
  end
  return shownAuras
end

local function updateGroupPositioning()
  for i, group in ipairs(groups) do
    local shownAuras = GetShownAurasOfGroup(group)
    local groupWidth = (#shownAuras * (config.auraSize + config.auraMargin) ) - config.auraMargin
    group.frame:SetSize(2, 2)
    group.frame:SetPoint("TOP", groupWidth / -2, ((i-1) * -config.auraSize) - ((i-1) * config.auraMargin) )
    -- group.frame.texture = mainFrame:CreateTexture(nil, "BACKGROUND")
    -- group.frame.texture:SetAllPoints(true)
    -- group.frame.texture:SetTexture(0, 0, 1, 1)
    -- group.frame.texture:SetColorTexture(0, 0, 1, 1)

    for i, aura in ipairs(shownAuras) do
      if aura:IsShown() then
        aura:SetPosition("TOPLEFT", (config.auraSize * (i-1)) + ((i-1) * config.auraMargin), 0)
      end
    end
  end
end
updateGroupPositioning()


local auras = {}
local PLAYER_GUID = ""
local function createAuras()
  PLAYER_GUID = UnitGUID("player")
  local _, class = UnitClass("player")
  local spec = select(2, GetSpecializationInfo(GetSpecialization()))
  local spellConfigs = AAENV.spells[class][spec]
  if not spellConfigs then
    print("No configuration found for class/spec", class, spec)
    return
  end

  for i, spellConfig in ipairs(spellConfigs) do
    local group = groups[spellConfig.group]
    local aura = AAura(group.frame, spellConfig.spellName, spellConfig.buffName)
    table.insert(group.auras, aura)
    auras[i] = aura
  end
  local raceName, raceFile, _ = UnitRace("player")
  local racialConfigs = AAENV.racials[raceFile]
  if not racialConfigs then
    print("No configuration found for race", raceName)
  else
    for i, spellConfig in ipairs(racialConfigs) do
      local group = groups[spellConfig.group]
      local aura = AAura(group.frame, spellConfig.spellName, spellConfig.buffName)
      table.insert(group.auras, aura)
      auras[i] = aura
    end
  end

  updateGroupPositioning()

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
  callHandlers("UpdateCooldown", lib.GetGcdInfo())
end

-- Throttle the checks to save some cpu cycles
local throttleUpdateRanges = 0.2
local sinceUpdateRange = 0
-- Handles the OnUpdate event, doing regular updates
local function updateHandler(self, elapsed)
  -- Update ranges periodically.
  -- No other events to check this from...
  sinceUpdateRange = sinceUpdateRange + elapsed
  if (sinceUpdateRange >= throttleUpdateRanges) then
    sinceUpdateRange = 0
    callHandlers("UpdateRange")
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
      callHandlers("BuffRemoved", arg[12])
    end
  elseif (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN") and #auras == 0 then
    createAuras()
    callHandlers("UpdateUsable")
  elseif event == "SPELL_UPDATE_USABLE" then
    callHandlers("UpdateUsable")
  end
end

mainFrame:SetScript("OnUpdate", updateHandler)
mainFrame:SetScript("OnEvent", eventHandler)
mainFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
mainFrame:RegisterEvent("SPELL_UPDATE_USABLE")
mainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("PLAYER_LOGIN")
