-- AAura.lua
-- Class for a single aura (icon)
-- Shows spell's cooldown and buff active

local AANAME, AAENV = ...
local lib = AAENV.lib
local config = AAENV.config

local function initAura(aura)
  aura.buff = {}
  aura.buff.name = aura.spellConfig.buffName
  aura.buffActive = false

  aura.spell = { name = nil, iconTexPath = nil, spellID = nil }
  aura.spell.name, _, aura.spell.iconTexPath, _, _, _,
    aura.spell.spellID = GetSpellInfo(aura.spellConfig.spellName)

    -- debug if
  -- if spellConfig.spellName == "Overpower" then
  --   print(spellConfig.spellName)
  --   print(spell) -- WTFWTFWTF
  --   print(GetSpellInfo(spellConfig.spellName))
  -- end -- end debug if

  local icon = aura.icon
  icon:SetFrameStrata("LOW")
  icon:SetWidth(config.auraSize)
  icon:SetHeight(config.auraSize)

  local tex = aura.texture
  tex:SetAllPoints(icon) -- hook to icon's frame
  -- set a texZoom on the texture to avoid the (ugly-ass) icon corners
  local texZoom = 0.07
  tex:SetTexCoord(0 + texZoom, 1 - texZoom, 0 + texZoom, 1 - texZoom)
  tex:SetTexture(aura.spell.iconTexPath) -- set as background texture

  local colorTexture = aura.colorTexture
  colorTexture:SetAllPoints(icon) -- hook to icon's frame
  colorTexture:SetColorTexture(0, 0, 0, 0)

  local cdSpin = aura.cdSpin
  cdSpin:SetAllPoints(icon)

  -- Can hold a C_Timer.NewTimer to track when the cooldown is supposed to finish
  aura.cdTimer = nil
  -- Stores the finish time of the cooldown (=when the self.cdTimer will elapse)
  aura.cdFinish = 0

  aura.canUse = {}
  aura.canUse.usable = nil
  aura.canUse.noMana = nil
  aura.canUse.inRange = nil
end

AAura = lib.class(function(aura, parentFrame, spellConfig)
  -- Set base configuration to identify this aura
  aura.spellConfig = spellConfig
  -- "main" icon frame
  aura.icon = CreateFrame("FRAME", nil, parentFrame, nil, nil);
  -- Background texture for the icon
  aura.texture = aura.icon:CreateTexture(nil, "BACKGROUND")
  -- Foreground texture for the red overlay
  aura.colorTexture = aura.icon:CreateTexture(nil, "OVERLAY")
  -- Cooldown frame for the icon
  aura.cdSpin = CreateFrame("COOLDOWN", nil, icon, "CooldownFrameTemplate");

  initAura(aura)
end)

function AAura:Initialize()
  initAura(self)
  self:Show()
end

function AAura:Remove()
  self:Hide()
  --TODO(aethyx): additional logic?
end

function AAura:Show()
  self.icon:Show()
end

function AAura:Hide()
  self.icon:Hide()
end

function AAura:IsShown()
  return self.icon:IsShown()
end

function AAura:SetPosition(point, x, y)
  self.icon:SetPoint(point, x, y)
end

function AAura:BuffApplied(name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod)
  -- we only want to continue  if...
  -- a) a spellID is set and matches given spellID
  -- b) no spellID is set, but a name is and it matches given name
  if self.buff.spellID then
    if self.buff.spellID ~= spellID then
      return
    end
  elseif not self.buff.name or self.buff.name ~= name then
    return
  end

  self.buffActive = true
  -- NOTE(aethyx): store spellID in case we don't have it yet (to match aura removal)
  self.buff.spellID = spellID
  self.cdSpin:SetReverse(true)
  self.texture:SetDesaturated(false)
  self.cdSpin:SetCooldown(expirationTime - duration, duration)
  -- TODO(aethyx): set glow effect
end

function AAura:BuffRemoved(spellID)
  if not self.buffActive or self.buff.spellID ~= spellID then
    return
  end
  self.buffActive = false
  -- Immediately update the cooldown swipe to the spell's cooldown
  self:UpdateCooldown(lib.GetGcdInfo())
  -- TODO(aethyx): remove glow effect
end

function AAura:UpdateCooldown(gcdInfo)
  if self.spell.name == 'Storm Bolt' then
    print("eyo")
  end
  -- Do nothing when our associated buff is active
  if self.buffActive or not self.spell.spellID then
    return
  end

  local start, duration, charges, maxCharges, modRate, matchesGCD = lib.GetSpellCooldownAndCharges(self.spell.spellID, gcdInfo)
  local finish = start + duration

  if duration and duration > 0 and self.cdFinish ~= finish then
    -- Something has changed in the cooldown, but it's not ready yet
    if self.timer then
      self.timer:Cancel()
      self.timer = nil
    end
    local _self = self
    self.timer = C_Timer.NewTimer(finish - GetTime(), function()
      _self:SetCooldownInactive()
    end)
    self:SetCooldownActive(start, duration, modRate)
  elseif duration == 0 and not matchesGCD then
    -- Duration ran out and doesn't match GCD = a proc/reset mechanic
    self:SetCooldownInactive()
  end
  self.cdFinish = finish
end

function AAura:SetCooldownActive(start, duration, modRate)
    -- Update/set the cooldown swipe
    self.cdSpin:SetReverse(false)
    self.texture:SetDesaturated(true)
    self.cdSpin:SetCooldown(start, duration, modRate)
    self.icon:SetAlpha(0.85)
end

function AAura:SetCooldownInactive()
  if self.timer then
    self.timer:Cancel()
    self.timer = nil
  end
  self.cdSpin:SetCooldown(0, 0)
  self.texture:SetDesaturated(false)
  self.icon:SetAlpha(1)
end

function AAura:CheckUsable()
  if self.spell.name then
    self.canUse.usable, self.canUse.noMana = IsUsableSpell(self.spell.name)
  else
    self.canUse.inRange = false
  end
end

function AAura:UpdateUsable()
  local blendmode = "BLEND"
  self.texture:SetBlendMode(blendmode)
  self.colorTexture:SetBlendMode(blendmode)

  self:CheckUsable()
  self:CheckRange() -- Also check range
  self:UpdateCanUse()
end

function AAura:CheckRange()
  if self.spell.name then
    self.canUse.inRange = IsSpellInRange(self.spell.name, "target")
  else
    self.canUse.inRange = false
  end
end

function AAura:UpdateRange()
  self:CheckRange()
  self:UpdateCanUse()
end

function AAura:UpdateCanUse()
  -- We don't disable the button if it's only because of resources that we can't cast the spell
  if (not self.canUse.usable and not self.canUse.noMana) or self.canUse.inRange == 0 then
  -- if self.canUse.inRange == 0 then
    -- Could do a different effect if self.canUse.noMana is true?
    self.colorTexture:SetColorTexture(1, 0, 0, 0.5)
  else
    self.colorTexture:SetColorTexture(0, 0, 0, 0)
  end
end
