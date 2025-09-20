if( not NotPlater ) then return end

local tgetn = table.getn
local tostring = tostring
local UnitGUID = UnitGUID
local UnitAffectingCombat = UnitAffectingCombat
local UnitInRaid = UnitInRaid
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitInParty = UnitInParty
local GetPartyMember = GetPartyMember
local UnitCanAttack = UnitCanAttack
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS
local MAX_RAID_MEMBERS = MAX_RAID_MEMBERS
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local Threat = {}

function Threat:GetThreat(unit, mobUnit)
	local isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation(unit, mobUnit)
	return threatValue
end

function Threat:GetMaxThreatOnTarget(unit, group)
	local maxThreat = 0
	for gMember,unitId in pairs(group) do
		local isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation(unitId, unit)
		if threatValue and threatValue > maxThreat then
			maxThreat = threatValue
		end
	end
	return maxThreat
end

local lastThreat = {}

function NotPlater:RAID_ROSTER_UPDATE()
	self.raid = nil
	if UnitInRaid("player") then
		self.raid = {}
		local raidNum = GetNumRaidMembers()
		local i = 1
		while raidNum > 0 and i <= MAX_RAID_MEMBERS do
			if GetRaidRosterInfo(i) then
				local guid = UnitGUID("raid" .. i)
				self.raid[guid] = "raid" .. i

				local pet = UnitGUID("raidpet" .. i)
				if pet then
					self.raid[pet] = "raidpet" .. i
				end
				raidNum = raidNum - 1
			end
			i = i + 1
		end
	end
end

function NotPlater:PARTY_MEMBERS_CHANGED()
	self.party = nil
	if UnitInParty("party1") then
		local partyNum = GetNumPartyMembers()
		local i = 1
		self.party = {}
		while partyNum > 0 and i < MAX_PARTY_MEMBERS do
			if GetPartyMember(i) then
				self.party[UnitGUID("party" .. i)] = "party" .. i
				local pet = UnitGUID("partypet" .. i)
				if pet then
					self.party[pet] = "partypet" .. i
				end
				partyNum = partyNum - 1
			end
			i = i + 1
		end
		self.party[UnitGUID("player")] = "player"
		local pet = UnitGUID("pet")
		if pet then
			self.party[pet] = "pet"
		end
	end
end

-- Add at the top of the file after local declarations
local threatColorCache = {}
local percentColorCache = {}

function NotPlater:OnNameplateMatch(healthFrame, group, ThreatLib)
	if not ThreatLib then ThreatLib = Threat end
	local threatConfig = self.db.profile.threat
	local frame = healthFrame:GetParent()
	
	-- Check if colored threat nameplates are disabled
	if not threatConfig.general.useColoredThreatNameplates then
		-- Apply class colors first if available and enabled
		if threatConfig.nameplateColors.general.useClassColors and frame.unitClass then
			healthFrame:SetStatusBarColor(frame.unitClass.r, frame.unitClass.g, frame.unitClass.b, 1)
		else
			-- Fall back to unit reaction colors
			local unit = healthFrame.lastUnitMatch
			if unit and UnitExists(unit) then
				local r, g, b = UnitSelectionColor(unit)
				if r and g and b then
					healthFrame:SetStatusBarColor(r, g, b, 1)
				elseif self.db.profile.healthBar.statusBar.general.enable then
					healthFrame:SetStatusBarColor(self:GetColor(self.db.profile.healthBar.statusBar.general.color))
				end
			elseif self.db.profile.healthBar.statusBar.general.enable then
				healthFrame:SetStatusBarColor(self:GetColor(self.db.profile.healthBar.statusBar.general.color))
			end
		end
		
		-- Hide threat indicators
		healthFrame.threatDifferentialText:Hide()
		healthFrame.threatNumberText:Hide()
		healthFrame.threatPercentBar:Hide()
		healthFrame.threatPercentText:Hide()
		return
	end
	
	-- Cache threat values to avoid repeated calls
	local unit = healthFrame.lastUnitMatch
	local playerThreat = ThreatLib:GetThreat("player", unit) or 0
	local playerThreatNumber = 1
	local highestThreat, highestThreatMember = ThreatLib:GetMaxThreatOnTarget(unit, group)
	local secondHighestThreat = 0
	
	if highestThreat and highestThreat > 0 then
		-- Pre-calculate threat values for all group members
		local groupThreatData = {}
		for gMember, gMemberUnitId in pairs(group) do
			local gMemberThreat = ThreatLib:GetThreat(gMemberUnitId, unit)
			if gMemberThreat then
				groupThreatData[gMember] = gMemberThreat
				if gMemberThreat ~= highestThreat and gMemberThreat > secondHighestThreat then
					secondHighestThreat = gMemberThreat
				end
				if gMemberThreat > playerThreat then
					playerThreatNumber = playerThreatNumber + 1
				end
			end
		end

		local mode = threatConfig.general.mode
		
		-- Cache color calculation to avoid repeated checks
		local colorKey = string.format("%s_%f_%f_%f", mode, playerThreat, highestThreat, secondHighestThreat)
		
		if threatConfig.nameplateColors.general.enable or threatConfig.differentialText.general.enable then
			local barColorConfig = threatConfig.nameplateColors.colors
			local textColorConfig = threatConfig.differentialText.colors
			
			if not threatColorCache[colorKey] then
				local barColor, textColor
				if mode == "hdps" then
					if highestThreat == playerThreat then
						barColor = barColorConfig[mode].c1
						textColor = textColorConfig[mode].c1
					elseif lastThreat[unit] and highestThreat - (playerThreat + 3*(playerThreat - lastThreat[unit])) < 0 then
						barColor = barColorConfig[mode].c2
						textColor = textColorConfig[mode].c2
					else
						barColor = barColorConfig[mode].c3
						textColor = textColorConfig[mode].c3
					end
				else -- "tank"
					if highestThreat == playerThreat then
						if lastThreat[unit] and (playerThreat - 3*(playerThreat - lastThreat[unit]) - secondHighestThreat) < 0 then
							barColor = barColorConfig[mode].c2
							textColor = textColorConfig[mode].c2
						else
							barColor = barColorConfig[mode].c1
							textColor = textColorConfig[mode].c1
						end
					else
						barColor = barColorConfig[mode].c3
						textColor = textColorConfig[mode].c3
					end
				end
				threatColorCache[colorKey] = {bar = barColor, text = textColor}
			end
			
			local colors = threatColorCache[colorKey]
			
			-- Apply nameplate color
			if self.db.profile.threat.nameplateColors.general.useClassColors and frame.unitClass then
				healthFrame:SetStatusBarColor(frame.unitClass.r, frame.unitClass.g, frame.unitClass.b, 1)
			elseif threatConfig.nameplateColors.general.enable then
				healthFrame:SetStatusBarColor(self:GetColor(colors.bar))
			end

			-- Update differential text
			if threatConfig.differentialText.general.enable then
				local threatDiff = (highestThreat == playerThreat) and 
					(playerThreat - secondHighestThreat) or 
					(highestThreat - playerThreat)

				healthFrame.threatDifferentialText:SetTextColor(self:GetColor(colors.text))
				if threatDiff < 1000 then
					healthFrame.threatDifferentialText:SetFormattedText("%.0f", threatDiff)
				else
					healthFrame.threatDifferentialText:SetFormattedText("%.1fk", threatDiff / 1000)
				end
				healthFrame.threatDifferentialText:Show()
			else
				healthFrame.threatDifferentialText:Hide()
			end
		end

		-- Number text (optimized)
		local numberTextConfig = threatConfig.numberText
		if numberTextConfig.general.enable then
			local groupSize = 0
			for _ in pairs(group) do groupSize = groupSize + 1 end
			
			local numberColorKey = string.format("%s_%d_%d", mode, playerThreatNumber, groupSize)
			if not percentColorCache[numberColorKey] then
				local numberColor
				if playerThreatNumber == 1 then
					numberColor = numberTextConfig.colors[mode].c1
				elseif playerThreatNumber / (groupSize - 1) < 0.2 then
					numberColor = numberTextConfig.colors[mode].c2
				else
					numberColor = numberTextConfig.colors[mode].c3
				end
				percentColorCache[numberColorKey] = numberColor
			end
			
			healthFrame.threatNumberText:SetTextColor(self:GetColor(percentColorCache[numberColorKey]))
			healthFrame.threatNumberText:SetText(tostring(playerThreatNumber))
			healthFrame.threatNumberText:Show()
		else
			healthFrame.threatNumberText:Hide()
		end

		-- Percent bar (optimized)
		local percentConfig = threatConfig.percent
		local threatPercent = playerThreat/highestThreat * 100
		
		if percentConfig.statusBar.general.enable then
			local percentKey = string.format("%s_%d", mode, math.floor(threatPercent / 10))
			if not percentColorCache[percentKey] then
				local barColor
				if threatPercent >= 100 then
					barColor = percentConfig.statusBar.colors[mode].c1
				elseif threatPercent >= 90 then
					barColor = percentConfig.statusBar.colors[mode].c2
				else
					barColor = percentConfig.statusBar.colors[mode].c3
				end
				percentColorCache[percentKey] = barColor
			end
			
			healthFrame.threatPercentBar:SetValue(threatPercent)
			local barColor = percentConfig.statusBar.general.useThreatColors and 
				percentColorCache[percentKey] or percentConfig.statusBar.general.color
			healthFrame.threatPercentBar:SetStatusBarColor(self:GetColor(barColor))
			healthFrame.threatPercentBar:Show()
		else
			healthFrame.threatPercentBar:Hide()
		end

		-- Percent text (optimized)
		if percentConfig.text.general.enable then
			local percentKey = string.format("%s_%d", mode, math.floor(threatPercent / 10))
			if not percentColorCache[percentKey .. "_text"] then
				local textColor
				if threatPercent >= 100 then
					textColor = percentConfig.text.colors[mode].c1
				elseif threatPercent >= 90 then
					textColor = percentConfig.text.colors[mode].c2
				else
					textColor = percentConfig.text.colors[mode].c3
				end
				percentColorCache[percentKey .. "_text"] = textColor
			end
			
			healthFrame.threatPercentText:SetFormattedText("%d%%", threatPercent)
			local textColor = percentConfig.text.general.useThreatColors and 
				percentColorCache[percentKey .. "_text"] or percentConfig.text.general.color
			healthFrame.threatPercentText:SetTextColor(self:GetColor(textColor))
			healthFrame.threatPercentText:Show()
		else
			healthFrame.threatPercentText:Hide()
		end

		lastThreat[unit] = playerThreat
	end
end

function NotPlater:MouseoverThreatCheck(healthFrame, guid)
	-- Safety check for nil healthFrame
	if not healthFrame then
		return
	end
	
	-- Safety check for healthFrame.parent
	local frame = healthFrame:GetParent()
	if not frame then
		return
	end
	
	-- Early exit if not in combat and mouseover updates are disabled
	if not self.db.profile.threat.general.enableMouseoverUpdate then
		return
	end
	
	-- Only process if we're in a group
	if UnitInParty("party1") or UnitInRaid("player") then
		healthFrame.lastUnitMatch = "mouseover"
		local group = self.raid or self.party
		if group then
			self:OnNameplateMatch(healthFrame, group)
		end
	else
		-- Apply class colors or default colors when solo
		if self.db.profile.threat.nameplateColors.general.useClassColors and frame.unitClass then
			healthFrame:SetStatusBarColor(frame.unitClass.r, frame.unitClass.g, frame.unitClass.b, 1)
		elseif self.db.profile.healthBar.statusBar.general.enable then
			healthFrame:SetStatusBarColor(self:GetColor(self.db.profile.healthBar.statusBar.general.color))
		end
	end
end

function NotPlater:ThreatCheck(frame)
    local healthBarConfig = self.db.profile.healthBar
    local threatConfig = self.db.profile.threat
    local unitId = frame.unitId

    if not unitId or UnitIsDeadOrGhost(unitId) then
        return
    end

    if self.db.profile.threat.general.useColoredThreatNameplates then
        local threatValue = UnitDetailedThreatSituation("player", unitId)

        -- If threatValue is nil, it means there is no threat information available.
        if threatValue then
            local r, g, b
            if threatConfig.general.mode == "tank" then
                if UnitIsUnit("player", unitId) then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatTanking.player)
                elseif threatValue >= 2 and threatValue <= 3 then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatTanking.c2)
                elseif threatValue >= 4 and threatValue <= 5 then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatTanking.c3)
                else
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatTanking.c1)
                end
            elseif threatConfig.general.mode == "hdps" then
                if threatValue == 1 then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatHealerDps.c1)
                elseif threatValue == 2 then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatHealerDps.c2)
                elseif threatValue == 3 then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatHealerDps.c3)
                elseif threatValue == 4 then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatHealerDps.c4)
                elseif threatValue == 5 then
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatHealerDps.c5)
                else
                    r, g, b = unpack(threatConfig.nameplateColors.colors.threatHealerDps.c1)
                end
            end
            frame.healthBar:SetStatusBarColor(r, g, b)
            frame.healthBar.healthText:SetTextColor(r, g, b)

            if frame.castBar then
                frame.castBar:SetStatusBarColor(r, g, b)
                frame.castBar.spellNameText:SetTextColor(r, g, b)
            end
        else
            -- If UnitDetailedThreatSituation returns nil, use default healthbar color
            local r, g, b
            if (frame.unitClass and threatConfig.nameplateColors.general.useClassColors and UnitIsPlayer(unitId) and not threatConfig.general.useColoredThreatNameplates) then
                r, g, b = unpack(frame.unitClass)
            else
                r, g, b = unpack(healthBarConfig.statusBar.colors.bar)
            end
            frame.healthBar:SetStatusBarColor(r, g, b)
            frame.healthBar.healthText:SetTextColor(r, g, b)

            if frame.castBar then
                frame.castBar:SetStatusBarColor(r, g, b)
                frame.castBar.spellNameText:SetTextColor(r, g, b)
            end
        end
    else
        -- Threat coloring is disabled, apply default healthbar color or class color
        local r, g, b
        if (frame.unitClass and threatConfig.nameplateColors.general.useClassColors and UnitIsPlayer(unitId)) then
            r, g, b = unpack(frame.unitClass)
        else
            r, g, b = unpack(healthBarConfig.statusBar.colors.bar)
        end
        frame.healthBar:SetStatusBarColor(r, g, b)
        frame.healthBar.healthText:SetTextColor(r, g, b)

        if frame.castBar then
            frame.castBar:SetStatusBarColor(r, g, b)
            frame.castBar.spellNameText:SetTextColor(r, g, b)
        end
    end
end

function NotPlater:ScaleThreatComponents(healthFrame, isTarget)
	local scaleConfig = self.db.profile.target.general.scale
	if scaleConfig.threat then
		local threatConfig = self.db.profile.threat
		local scalingFactor = isTarget and scaleConfig.scalingFactor or 1
		self:ScaleGeneralisedStatusBar(healthFrame.threatPercentBar, scalingFactor, threatConfig.percent.statusBar)
		self:ScaleGeneralisedText(healthFrame.threatPercentText, scalingFactor, threatConfig.percent.text)
		self:ScaleGeneralisedText(healthFrame.threatDifferentialText, scalingFactor, threatConfig.differentialText)
		self:ScaleGeneralisedText(healthFrame.threatNumberText, scalingFactor, threatConfig.numberText)
	end
end

function NotPlater:ThreatComponentsOnShow(frame)
	local healthFrame = frame.healthBar
	-- Ensure fonts are set before trying to set text
	if healthFrame.threatDifferentialText then
		if not healthFrame.threatDifferentialText:GetFont() then
			self:ConfigureGeneralisedText(healthFrame.threatDifferentialText, healthFrame, self.db.profile.threat.differentialText)
		end
		healthFrame.threatDifferentialText:SetText("")
	end
	
	if healthFrame.threatNumberText then
		if not healthFrame.threatNumberText:GetFont() then
			self:ConfigureGeneralisedText(healthFrame.threatNumberText, healthFrame, self.db.profile.threat.numberText)
		end
		healthFrame.threatNumberText:SetText("")
	end
	
	if healthFrame.threatPercentText then
		if not healthFrame.threatPercentText:GetFont() then
			self:ConfigureGeneralisedText(healthFrame.threatPercentText, healthFrame.threatPercentBar, self.db.profile.threat.percent.text)
		end
		healthFrame.threatPercentText:SetText("")
	end
	
	if healthFrame.threatPercentBar then
		healthFrame.threatPercentBar:Hide()
	end
	
	healthFrame.lastUnitMatch = nil
	self:ThreatCheck(frame)
end

function NotPlater:ConfigureThreatComponents(frame)
	local healthFrame = frame.healthBar
	local threatConfig = self.db.profile.threat
	-- Set differential text
	self:ConfigureGeneralisedText(healthFrame.threatDifferentialText, healthFrame, threatConfig.differentialText)

	-- Set number text
	self:ConfigureGeneralisedText(healthFrame.threatNumberText, healthFrame, threatConfig.numberText)

	-- Set percent text
	self:ConfigureGeneralisedText(healthFrame.threatPercentText, healthFrame.threatPercentBar, threatConfig.percent.text)

	-- Set percent bar
	self:ConfigureGeneralisedPositionedStatusBar(healthFrame.threatPercentBar, healthFrame, threatConfig.percent.statusBar)

	self:ThreatCheck(frame)
end

function NotPlater:ConstructThreatComponents(healthFrame)
	healthFrame:SetFrameLevel(healthFrame:GetParent():GetFrameLevel() + 1)

    -- Create threat text
    healthFrame.threatDifferentialText = healthFrame:CreateFontString(nil, "ARTWORK")
    healthFrame.threatNumberText = healthFrame:CreateFontString(nil, "ARTWORK")

	-- Percent text
    healthFrame.threatPercentText = healthFrame:CreateFontString(nil, "OVERLAY")

	-- Percent bar
    healthFrame.threatPercentBar = CreateFrame("StatusBar", nil, healthFrame)
	self:ConstructGeneralisedStatusBar(healthFrame.threatPercentBar)
    healthFrame.threatPercentBar:SetMinMaxValues(0, 100)
    healthFrame.threatPercentBar:SetFrameLevel(healthFrame:GetFrameLevel() - 1)
    healthFrame.threatPercentBar:Hide()
end