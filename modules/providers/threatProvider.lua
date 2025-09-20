-- modules/providers/threatProvider.lua
-- Threat-based color provider

if not NotPlater then return end

local ThreatProvider = {}
NotPlater.ThreatProvider = ThreatProvider

-- Local references
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local UnitExists = UnitExists
local GetTime = GetTime

-- Threat color cache
local threatColorCache = {}
local lastThreatUpdate = {}

-- Initialize threat provider
function ThreatProvider:Initialize()
    -- Clear caches
    threatColorCache = {}
    lastThreatUpdate = {}
end

-- Get threat-based color for nameplate
function ThreatProvider:GetThreatColor(frame)
    if not frame or not frame.unit then
        return nil, nil
    end
    
    -- Check if threat coloring is enabled
    if not NotPlater.db.profile.threat.general.useColoredThreatNameplates then
        return nil, nil
    end
    
    -- Only in combat
    if not UnitAffectingCombat("player") then
        return nil, nil
    end
    
    local unit = frame.unit
    if not UnitExists(unit) then
        return nil, nil
    end
    
    -- Get threat situation
    local isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation("player", unit)
    
    -- Get mode (tank/dps)
    local mode = NotPlater.db.profile.threat.general.mode
    local colors = NotPlater.db.profile.threat.nameplateColors.colors
    
    -- Determine color based on threat and role
    local color = nil
    local colorType = "threat_" .. mode
    
    if mode == "tank" then
        if isTanking then
            -- Has aggro - good for tank
            color = colors.tank.c1
        elseif status and status >= 2 then
            -- Losing aggro - warning
            color = colors.tank.c2
        else
            -- No aggro - bad for tank
            color = colors.tank.c3
        end
    else -- DPS/Healer mode
        if isTanking then
            -- Has aggro - bad for DPS
            color = colors.hdps.c1
        elseif status and status >= 2 then
            -- High threat - warning
            color = colors.hdps.c2
        else
            -- Low threat - good for DPS
            color = colors.hdps.c3
        end
    end
    
    if color then
        return {
            r = color[1],
            g = color[2],
            b = color[3]
        }, colorType
    end
    
    return nil, nil
end

-- Get detailed threat information
function ThreatProvider:GetThreatInfo(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    
    local isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation("player", unit)
    
    return {
        isTanking = isTanking,
        status = status,
        scaledPercent = scaledPercent,
        rawPercent = rawPercent,
        threatValue = threatValue,
        timestamp = GetTime()
    }
end

-- Calculate threat differential
function ThreatProvider:GetThreatDifferential(unit, group)
    if not unit or not group then
        return 0, nil
    end
    
    local playerThreat = self:GetPlayerThreat(unit) or 0
    local maxThreat, maxThreatUnit = self:GetMaxGroupThreat(unit, group)
    
    if maxThreat and maxThreat > 0 then
        if playerThreat >= maxThreat then
            -- Player has aggro, calculate lead
            local secondHighest = self:GetSecondHighestThreat(unit, group, maxThreat)
            return playerThreat - secondHighest, "leading"
        else
            -- Player doesn't have aggro, calculate deficit
            return maxThreat - playerThreat, "trailing"
        end
    end
    
    return 0, nil
end

-- Get player threat value
function ThreatProvider:GetPlayerThreat(unit)
    if not unit or not UnitExists(unit) then
        return 0
    end
    
    local _, _, _, _, threatValue = UnitDetailedThreatSituation("player", unit)
    return threatValue or 0
end

-- Get maximum threat in group
function ThreatProvider:GetMaxGroupThreat(unit, group)
    if not unit or not group then
        return 0, nil
    end
    
    local maxThreat = 0
    local maxThreatUnit = nil
    
    for guid, unitId in pairs(group) do
        local _, _, _, _, threatValue = UnitDetailedThreatSituation(unitId, unit)
        if threatValue and threatValue > maxThreat then
            maxThreat = threatValue
            maxThreatUnit = unitId
        end
    end
    
    return maxThreat, maxThreatUnit
end

-- Get second highest threat
function ThreatProvider:GetSecondHighestThreat(unit, group, excludeValue)
    if not unit or not group then
        return 0
    end
    
    local secondHighest = 0
    
    for guid, unitId in pairs(group) do
        local _, _, _, _, threatValue = UnitDetailedThreatSituation(unitId, unit)
        if threatValue and threatValue < excludeValue and threatValue > secondHighest then
            secondHighest = threatValue
        end
    end
    
    return secondHighest
end

-- Clear threat cache
function ThreatProvider:ClearCache()
    threatColorCache = {}
    lastThreatUpdate = {}
end