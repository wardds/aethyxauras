-- AAura.lua
-- Class for a single aura (icon)
-- Shows spell's cooldown and buff active

local AANAME, AAENV = ...
local lib = AAENV.lib
local config = AAENV.config

AAura = lib.class(function(aura, index, parentFrame, spellIdentifier, buffIdentifier)
  local buff = {}
  buff.name = buffIdentifier

  local spell = {}
  spell.name, _, spell.iconTexPath, _, _, _, spell.spellID
    = GetSpellInfo(spellIdentifier)

  -- "main" icon frame
  local icon = CreateFrame("FRAME", nil, parentFrame, nil, nil);
  icon:SetFrameStrata("LOW")
  local myIndex = index -1
  icon:SetPoint("TOPLEFT", (config.auraSize * myIndex) + (myIndex * config.auraMargin), 0)
  icon:SetWidth(config.auraSize)
  icon:SetHeight(config.auraSize)

  -- Background texture for the icon
  local tex = icon:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints(icon) -- hook to icon's frame
  tex:SetTexture(spell.iconTexPath) -- set as background texture
  -- set a texZoom on the texture to avoid the (ugly-ass) icon corners
  local texZoom = 0.07
  tex:SetTexCoord(0 + texZoom, 1 - texZoom, 0 + texZoom, 1 - texZoom)

  -- Cooldown frame for the icon
  local cdSpin = CreateFrame("COOLDOWN", nil, icon, "CooldownFrameTemplate");
  cdSpin:SetAllPoints(icon)

  aura.buffActive = false

  aura.spell = spell
  aura.buff = buff
  aura.icon = icon
  aura.texture = tex
  aura.cdSpin = cdSpin
end)

function AAura:Show()
  self.icon:Show()
end

function AAura:Hide()
  self.icon:Hide()
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
  -- immediately update the cooldown swipe to the spell's cooldown
  self:UpdateCooldown(lib.GetGcdEnd())
  -- TODO(aethyx): remove glow effect
end

function AAura:UpdateCooldown(gcdEnd)
  if self.buffActive then
    -- Do nothing when our associated buff is active
    return
  end

  local start, duration, enabled, modRate = GetSpellCooldown(self.spell.spellID)
  if not enabled then
    print("spell cooldown not enabled! " .. self.spell.name)
  elseif start + duration <= gcdEnd then
    -- Spell not on cooldown or ends before GCD does, so ignore
    self.texture:SetDesaturated(false)
    self.icon:SetAlpha(1)
  else
    -- Update/set the cooldown swipe
    self.cdSpin:SetReverse(false)
    self.texture:SetDesaturated(true)
    self.cdSpin:SetCooldown(start, duration, modRate)
    self.icon:SetAlpha(0.85)
  end
end
