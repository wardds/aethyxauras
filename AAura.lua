-- AAura.lua
-- Class for a single aura (icon)
-- Shows spell's cooldown and buff active

local AANAME, AAENV = ...
local lib = AAENV.lib
local config = AAENV.config

AAura = lib.class(function(aura, parentFrame, spellIdentifier, buffIdentifier)
  local buff = {}
  buff.name = buffIdentifier

  local spell = {}
  spell.name, _, spell.iconTexPath, _, _, _, spell.spellID
    = GetSpellInfo(spellIdentifier)

  -- "main" icon frame
  local icon = CreateFrame("FRAME", nil, parentFrame, nil, nil);
  icon:SetFrameStrata("LOW")
  icon:SetWidth(config.auraSize)
  icon:SetHeight(config.auraSize)

  -- Background texture for the icon
  local tex = icon:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints(icon) -- hook to icon's frame
  tex:SetTexture(spell.iconTexPath) -- set as background texture
  -- set a texZoom on the texture to avoid the (ugly-ass) icon corners
  local texZoom = 0.07
  tex:SetTexCoord(0 + texZoom, 1 - texZoom, 0 + texZoom, 1 - texZoom)

  -- Foreground texture for the red overlay
  local colorTexture = icon:CreateTexture(nil, "OVERLAY")
  colorTexture:SetAllPoints(icon) -- hook to icon's frame
  colorTexture:SetColorTexture(0, 0, 0, 0)

  -- Cooldown frame for the icon
  local cdSpin = CreateFrame("COOLDOWN", nil, icon, "CooldownFrameTemplate");
  cdSpin:SetAllPoints(icon)

  aura.spell = spell
  aura.buff = buff
  aura.icon = icon
  aura.texture = tex
  aura.colorTexture = colorTexture
  aura.cdSpin = cdSpin

  aura.buffActive = false

  -- Can hold a C_Timer.NewTimer to track when the cooldown is supposed to finish
  aura.cdTimer = nil
  -- Stores the finish time of the cooldown (=when the self.cdTimer will elapse)
  aura.cdFinish = 0

  aura.canUse = {}
  aura.canUse.usable = nil
  aura.canUse.noMana = nil
  aura.canUse.inRange = nil
end)

function AAura:Show()
  self.icon:Show()
end

function AAura:Hide()
  self.icon:Hide()
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
  -- Do nothing when our associated buff is active
  if self.buffActive then
    return
  end

  local start, duration, charges, maxCharges, modRate = lib.GetSpellCooldownAndCharges(self.spell.spellID, gcdInfo)
  local finish = start + duration

  if duration and duration > 0 and self.cdFinish ~= finish then
    -- Something has changed in the cooldown, but it's not ready yet
    if self.timer then
      self.timer:Cancel()
      self.timer = nil
    end
    local _self = self
    self.timer = C_Timer.NewTimer(finish - GetTime(), function(self)
      _self.timer = nil
      _self:UpdateCooldown(lib.GetGcdInfo())
    end)
    -- Update/set the cooldown swipe
    self.cdSpin:SetReverse(false)
    self.texture:SetDesaturated(true)
    self.cdSpin:SetCooldown(start, duration, modRate)
    self.icon:SetAlpha(0.85)
  elseif duration == 0 then
    -- No duration but the timer still running, it's a reset or cd reduction
    if self.timer then
      self.cdSpin:SetCooldown(start, duration)
      self.timer:Cancel()
      self.timer = nil
    end
    self.texture:SetDesaturated(false)
    self.icon:SetAlpha(1)
  end
  self.cdFinish = finish
end

function AAura:CheckUsable()
  self.canUse.usable, self.canUse.noMana = IsUsableSpell(self.spell.name)
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
  self.canUse.inRange = IsSpellInRange(self.spell.name, "target")
end

function AAura:UpdateRange()
  self:CheckRange()
  self:UpdateCanUse()
end

function AAura:UpdateCanUse()
  local canUse = self.canUse
  if not canUse.usable or canUse.inRange == 0 then
    -- Could do a different effect if canUse.noMana is true?
    self.colorTexture:SetColorTexture(1, 0, 0, 0.5)
  else
    self.colorTexture:SetColorTexture(0, 0, 0, 0)
  end
end
