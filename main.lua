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
rlui.texture = rlui:CreateTexture(nil, "BACKGROUND")
rlui.texture:SetAllPoints(rlui)
rlui.texture:SetTexture(select(3, GetSpellInfo("Auto Attack")))
rlui:SetScript("OnClick", function() ReloadUI() end)

-- main frame, containing auras and event registrations
local mainFrame = CreateFrame("FRAME", nil, UIParent, nil, nil)
mainFrame:SetFrameStrata("LOW")
mainFrame:SetSize(5, 5)
mainFrame:SetPoint("BOTTOM", 0, 480)
mainFrame.texture = mainFrame:CreateTexture(nil, "BACKGROUND")
mainFrame.texture:SetAllPoints(true)
mainFrame.texture:SetTexture(1, 0, 0, 1)
mainFrame.texture:SetColorTexture(1, 0, 0, 1)

local PLAYER_GUID = ""
local ALL_CONFIGS = {}
local ALL_AURAS = {}
-- Each group is 1 horizontal "bar" of auras
local ALL_GROUPS = {
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

local function SET_ALL_CONFIGS()
  local _, class = UnitClass("player")
  local spec = select(2, GetSpecializationInfo(GetSpecialization()))
  local raceName, raceFile, _ = UnitRace("player")

    local spellConfigs = AAENV.spells[class][spec]
  if not spellConfigs then
    spellConfigs = {}
    print("No configuration found for " .. lib.StrCapitalized(class) .. "/" .. lib.StrCapitalized(spec))
  end
  local racialConfigs = AAENV.racials[raceFile]
  if not racialConfigs then
    racialConfigs = {}
    print("No configuration found for " .. lib.StrCapitalized(raceName))
  end
  for i=1, #racialConfigs do
    spellConfigs[#spellConfigs+1] = racialConfigs[i]
  end
  ALL_CONFIGS = spellConfigs
  return spellConfigs
end

local function SET_PLAYER_GUID()
  PLAYER_GUID = UnitGUID("player")
end

local function SET_EMPTY_GROUPS()
  for i, group in ipairs(ALL_GROUPS) do
    group.auras = {}
  end
end

local function REMOVE_ALL_AURAS()
  for i, aura in ipairs(ALL_AURAS) do
    aura:Remove()
  end
end

local function updateGroupPositioning()
  for i, group in ipairs(ALL_GROUPS) do
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

local function isSameSpellConfig(c1, c2)
  return (c1.spellName == c2.spellName
    and c1.buffName == c2.buffName
    and c1.group == c2.group)
end

local function findAAura(auras, spellConfig)
  for i, aura in ipairs(auras) do
    if isSameSpellConfig(aura.spellConfig, spellConfig) then
      return i, aura
    end
  end
  return nil, nil
end

local function findConfig(spellConfigs, aura)
  for i, config in ipairs(spellConfigs) do
    if isSameSpellConfig(config, aura.spellConfig) then
      return config
    end
  end
  return nil
end

-- Calls `func` on all AAuras with given parameters
local function callHandlers(func, ...)
  for i, group in ipairs(ALL_GROUPS) do
    for j, aura in ipairs(group.auras) do
      if aura[func] then
        aura[func](aura, ...)
      end
    end
  end
end

-- Ensures all configured auras are made.
-- Performance improvement possible here by checking existing auras.
-- When e.g. changing talents, there would be no need to recreate all auras.
local function INITIALIZE()
  SET_EMPTY_GROUPS()
  REMOVE_ALL_AURAS()

  -- recreate all auras
  for i, config in ipairs(ALL_CONFIGS) do
    local group = ALL_GROUPS[config.group]
    if WeakAuras.IsSpellKnownIncludingPet(config.spellName) then
      local ai, aura = findAAura(ALL_AURAS, config)
      if aura == nil then
        aura = AAura(group.frame, config)
        table.insert(ALL_AURAS, aura)
      end
      table.insert(group.auras, aura)
      aura:Initialize()
    end
  end
  -- Update UI and states
  updateGroupPositioning()
  callHandlers("UpdateUsable")
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
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
    print(event, ...)
  end

  if event == "SPELL_UPDATE_COOLDOWN" then
    callHandlers("UpdateCooldown", lib.GetGcdInfo())
  elseif event == "SPELL_UPDATE_USABLE" then
    callHandlers("UpdateUsable")
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
  elseif (event == "PLAYER_LOGIN") then
    SET_ALL_CONFIGS()
  elseif (event == "PLAYER_ENTERING_WORLD") then
    SET_PLAYER_GUID()
  elseif event == "SPELLS_CHANGED" then
    INITIALIZE()
  end
end

mainFrame:SetScript("OnUpdate", updateHandler)
mainFrame:SetScript("OnEvent", eventHandler)
mainFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
mainFrame:RegisterEvent("SPELL_UPDATE_USABLE")
mainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
mainFrame:RegisterEvent("SPELLS_CHANGED")
