-- modules/threat/threatComponents.lua
-- Simplified threat component handling without color management

if not NotPlater then return end

local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local GetTime = GetTime
local tostring = tostring

-- Threat tracking
local lastThreat = {}

-- Simplified threat check - only updates threat UI components, not colors
function NotPlater:ThreatCheck(frame)
    -- Color management is now handled by ColorManager
    -- This function only handles threat UI components
    
    local healthFrame = frame.healthBar
    if not healthFrame then return end
    
    -- Update threat components visibility based on combat/threat status
    if not self.db.profile.threat.general.useColoredThreatNameplates then
        -- Hide all threat components
        if healthFrame.threatDifferentialText then
            healthFrame.threatDifferentialText:Hide()
        end
        if healthFrame.threatNumberText then
            healthFrame.threatNumberText:Hide()
        end
        if healthFrame.threatPercentBar then
            healthFrame.threatPercentBar:Hide()
        end
        if healthFrame.threatPercentText then
            healthFrame.threatPercentText:Hide()
        end
        return
    end
    
    -- If we have a unit match, update threat components
    if healthFrame.lastUnitMatch then
        local group = self.raid or self.party
        if group then
            self:UpdateThreatComponents(healthFrame, group)
        end
    end
end

-- Update threat UI components (text, bars) with simulator support
function NotPlater:UpdateThreatComponents(healthFrame, group, simulatedData)
    -- Check if this is simulated data
    if simulatedData then
        -- Use simulated threat values
        self:UpdateSimulatedThreatComponents(healthFrame, simulatedData)
        return
    end
    
    local unit = healthFrame.lastUnitMatch
    if not unit or not UnitExists(unit) then
        return
    end
    
    -- Get threat values
    local playerThreat = 0
    local maxThreat = 0
    local secondHighest = 0
    local playerRank = 1
    
    -- Calculate threat values
    local _, _, _, _, myThreatValue = UnitDetailedThreatSituation("player", unit)
    playerThreat = myThreatValue or 0
    
    -- Find max threat and player rank
    for guid, unitId in pairs(group) do
        local _, _, _, _, threatValue = UnitDetailedThreatSituation(unitId, unit)
        if threatValue then
            if threatValue > maxThreat then
                secondHighest = maxThreat
                maxThreat = threatValue
            elseif threatValue > secondHighest and threatValue < maxThreat then
                secondHighest = threatValue
            end
            
            if threatValue > playerThreat then
                playerRank = playerRank + 1
            end
        end
    end
    
    -- Update components
    self:UpdateThreatDisplayComponents(healthFrame, playerThreat, maxThreat, secondHighest, playerRank)
    
    -- Store last threat for velocity calculations
    lastThreat[unit] = playerThreat
end

-- Update simulated threat components
function NotPlater:UpdateSimulatedThreatComponents(healthFrame, simulatedData)
    -- Extract simulated values
    local playerThreat = simulatedData.playerThreat or 0
    local maxThreat = simulatedData.maxThreat or 0
    local secondHighest = simulatedData.secondHighest or 0
    local playerRank = simulatedData.playerRank or 1
    
    -- Update display components
    self:UpdateThreatDisplayComponents(healthFrame, playerThreat, maxThreat, secondHighest, playerRank)
end

-- Update the display components (shared by real and simulated)
function NotPlater:UpdateThreatDisplayComponents(healthFrame, playerThreat, maxThreat, secondHighest, playerRank)
    -- Update differential text
    if self.db.profile.threat.differentialText.general.enable then
        local threatDiff = 0
        if playerThreat >= maxThreat and maxThreat > 0 then
            threatDiff = playerThreat - secondHighest
        else
            threatDiff = maxThreat - playerThreat
        end
        
        if threatDiff < 1000 then
            healthFrame.threatDifferentialText:SetFormattedText("%.0f", threatDiff)
        else
            healthFrame.threatDifferentialText:SetFormattedText("%.1fk", threatDiff / 1000)
        end
        healthFrame.threatDifferentialText:Show()
    else
        healthFrame.threatDifferentialText:Hide()
    end
    
    -- Update number text
    if self.db.profile.threat.numberText.general.enable then
        healthFrame.threatNumberText:SetText(tostring(playerRank))
        healthFrame.threatNumberText:Show()
    else
        healthFrame.threatNumberText:Hide()
    end
    
    -- Update percent bar
    if self.db.profile.threat.percent.statusBar.general.enable and maxThreat > 0 then
        local percent = (playerThreat / maxThreat) * 100
        healthFrame.threatPercentBar:SetValue(percent)
        healthFrame.threatPercentBar:Show()
    else
        healthFrame.threatPercentBar:Hide()
    end
    
    -- Update percent text
    if self.db.profile.threat.percent.text.general.enable and maxThreat > 0 then
        local percent = (playerThreat / maxThreat) * 100
        healthFrame.threatPercentText:SetFormattedText("%d%%", percent)
        healthFrame.threatPercentText:Show()
    else
        healthFrame.threatPercentText:Hide()
    end
end

-- Scale threat components
function NotPlater:ScaleThreatComponents(healthFrame, isTarget)
    local scaleConfig = self.db.profile.target.general.scale
    if scaleConfig.threat then
        local threatConfig = self.db.profile.threat
        local scalingFactor = isTarget and scaleConfig.scalingFactor or 1
        
        if healthFrame.threatPercentBar then
            self:ScaleGeneralisedStatusBar(healthFrame.threatPercentBar, scalingFactor, threatConfig.percent.statusBar)
        end
        if healthFrame.threatPercentText then
            self:ScaleGeneralisedText(healthFrame.threatPercentText, scalingFactor, threatConfig.percent.text)
        end
        if healthFrame.threatDifferentialText then
            self:ScaleGeneralisedText(healthFrame.threatDifferentialText, scalingFactor, threatConfig.differentialText)
        end
        if healthFrame.threatNumberText then
            self:ScaleGeneralisedText(healthFrame.threatNumberText, scalingFactor, threatConfig.numberText)
        end
    end
end

-- Threat components on show
function NotPlater:ThreatComponentsOnShow(frame)
    local healthFrame = frame.healthBar
    if not healthFrame then return end
    
    -- Ensure fonts are set
    if healthFrame.threatDifferentialText and not healthFrame.threatDifferentialText:GetFont() then
        self:ConfigureGeneralisedText(healthFrame.threatDifferentialText, healthFrame, self.db.profile.threat.differentialText)
    end
    
    if healthFrame.threatNumberText and not healthFrame.threatNumberText:GetFont() then
        self:ConfigureGeneralisedText(healthFrame.threatNumberText, healthFrame, self.db.profile.threat.numberText)
    end
    
    if healthFrame.threatPercentText and not healthFrame.threatPercentText:GetFont() then
        self:ConfigureGeneralisedText(healthFrame.threatPercentText, healthFrame.threatPercentBar, self.db.profile.threat.percent.text)
    end
    
    -- Hide all initially
    if healthFrame.threatDifferentialText then
        healthFrame.threatDifferentialText:SetText("")
        healthFrame.threatDifferentialText:Hide()
    end
    if healthFrame.threatNumberText then
        healthFrame.threatNumberText:SetText("")
        healthFrame.threatNumberText:Hide()
    end
    if healthFrame.threatPercentText then
        healthFrame.threatPercentText:SetText("")
        healthFrame.threatPercentText:Hide()
    end
    if healthFrame.threatPercentBar then
        healthFrame.threatPercentBar:Hide()
    end
    
    healthFrame.lastUnitMatch = nil
    self:ThreatCheck(frame)
end

-- Configure threat components
function NotPlater:ConfigureThreatComponents(frame)
    local healthFrame = frame.healthBar
    if not healthFrame then return end
    
    local threatConfig = self.db.profile.threat
    
    -- Configure text elements
    if healthFrame.threatDifferentialText then
        self:ConfigureGeneralisedText(healthFrame.threatDifferentialText, healthFrame, threatConfig.differentialText)
    end
    
    if healthFrame.threatNumberText then
        self:ConfigureGeneralisedText(healthFrame.threatNumberText, healthFrame, threatConfig.numberText)
    end
    
    if healthFrame.threatPercentText then
        self:ConfigureGeneralisedText(healthFrame.threatPercentText, healthFrame.threatPercentBar, threatConfig.percent.text)
    end
    
    -- Configure percent bar
    if healthFrame.threatPercentBar then
        self:ConfigureGeneralisedPositionedStatusBar(healthFrame.threatPercentBar, healthFrame, threatConfig.percent.statusBar)
    end
    
    self:ThreatCheck(frame)
end

-- Construct threat components
function NotPlater:ConstructThreatComponents(healthFrame)
    if not healthFrame then return end
    
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