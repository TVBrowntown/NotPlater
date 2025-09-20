-- modules/threat/threatIcon.lua
-- Refactored threat icon module with cleaner integration

if not NotPlater then return end

local ThreatIcon = {}
NotPlater.ThreatIcon = ThreatIcon

-- Local references
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitIsPlayer = UnitIsPlayer
local UnitCreatureType = UnitCreatureType
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitPlayerControlled = UnitPlayerControlled
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local GetTime = GetTime
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers

-- Icon paths
local THREAT_ICON_PATHS = {
    tank = [[Interface\AddOns\NotPlater\images\icons\tank]],
    aggro = [[Interface\AddOns\NotPlater\images\icons\aggro]]
}

-- Color definitions for threat states
local THREAT_COLORS = {
    green = {r = 0, g = 1, b = 0},        -- Safe/Tanking properly
    blue = {r = 0, g = 0.75, b = 1},      -- Other tank has aggro
    yellow = {r = 1, g = 0.90, b = 0},    -- Warning (50-75% threat)
    orange = {r = 1, g = 0.5, b = 0},     -- High threat (75-100%)
    red = {r = 1, g = 0, b = 0}           -- Has aggro/Lost aggro
}

-- Cache for tracking threat state per GUID
local threatStateCache = {}
local cacheCleanupTimer = 0

-- Initialize threat icon module
function ThreatIcon:Initialize()
    threatStateCache = {}
    cacheCleanupTimer = 0
    
    -- Set up cleanup timer
    self:SetupCleanupTimer()
end

-- Set up cleanup timer for threat cache
function ThreatIcon:SetupCleanupTimer()
    local cleanupFrame = CreateFrame("Frame")
    cleanupFrame.elapsed = 0
    cleanupFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 5 then
            self.elapsed = 0
            ThreatIcon:CleanThreatCache()
        end
    end)
end

-- Clean up old threat cache entries
function ThreatIcon:CleanThreatCache()
    local currentTime = GetTime()
    for guid, data in pairs(threatStateCache) do
        if currentTime - data.timestamp > 10 then
            threatStateCache[guid] = nil
        end
    end
end

-- Check if unit is a player's pet
function ThreatIcon:IsUnitPlayerPet(unit)
    if not unit or not UnitExists(unit) then return false end
    
    if not UnitPlayerControlled(unit) or UnitIsPlayer(unit) then
        return false
    end
    
    local unitName = UnitName(unit)
    if not unitName then return false end
    
    -- Check for pet patterns
    if string.find(unitName, "'s Pet") or 
       string.find(unitName, "'s Minion") or 
       string.find(unitName, "'s Ghoul") or
       string.find(unitName, "'s Imp") or
       string.find(unitName, "'s Voidwalker") or
       string.find(unitName, "'s Succubus") or
       string.find(unitName, "'s Felhunter") or
       string.find(unitName, "'s Felguard") or
       string.find(unitName, "'s Water Elemental") then
        return true
    end
    
    local creatureType = UnitCreatureType(unit)
    if creatureType then
        if (creatureType == "Demon" or creatureType == "Elemental") and UnitPlayerControlled(unit) then
            return true
        end
        if creatureType == "Beast" and UnitPlayerControlled(unit) then
            return true
        end
    end
    
    return false
end

-- Check if in group
function ThreatIcon:IsInGroup()
    return GetNumPartyMembers() > 0
end

-- Check if in raid
function ThreatIcon:IsInRaid()
    return GetNumRaidMembers() > 0
end

-- Find unit for nameplate
function ThreatIcon:FindUnitForNameplate(frame)
    if not frame then return nil end
    
    local nameText, levelText = select(7, frame:GetRegions())
    if not nameText or not levelText then return nil end
    
    local name = nameText:GetText()
    local level = levelText:GetText()
    if not name or not level then return nil end
    
    -- Check common units
    local unitsToCheck = {"target", "mouseover", "focus"}
    
    -- Add party/raid targets
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            table.insert(unitsToCheck, "raid" .. i .. "-target")
        end
    elseif self:IsInGroup() then
        for i = 1, GetNumPartyMembers() do
            table.insert(unitsToCheck, "party" .. i .. "-target")
        end
    end
    
    -- Find matching unit
    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) and 
           name == UnitName(unit) and 
           level == tostring(UnitLevel(unit)) then
            local guid = UnitGUID(unit)
            if guid then
                frame.unitGUID = guid
                return unit
            end
        end
    end
    
    return nil
end

-- Check if threat icon should be visible
function ThreatIcon:ShouldShowIcon(frame, config)
    if not config or not config.general or not config.general.enable then
        return false
    end
    
    -- Check visibility mode
    local showIcon = false
    if config.general.visibility == "always" then
        showIcon = true
    elseif config.general.visibility == "combat" then
        showIcon = UnitAffectingCombat("player")
    elseif config.general.visibility == "group" then
        showIcon = (self:IsInRaid() or self:IsInGroup())
    end
    
    return showIcon
end

-- Update threat state cache
function ThreatIcon:UpdateThreatCache(unit, guid)
    if not unit or not guid or not UnitExists(unit) then
        return
    end
    
    local isTanking, status = UnitDetailedThreatSituation("player", unit)
    
    if isTanking or (status and status > 0) then
        threatStateCache[guid] = {
            isTanking = isTanking,
            status = status,
            timestamp = GetTime(),
            unitName = UnitName(unit)
        }
    elseif threatStateCache[guid] then
        threatStateCache[guid] = nil
    end
end

-- Get threat color and icon for tank
function ThreatIcon:GetTankThreatVisuals(isTanking, otherTankHasAggro, inCombat)
    local color, iconPath
    
    if isTanking then
        color = THREAT_COLORS.green
    elseif otherTankHasAggro then
        color = THREAT_COLORS.blue
    elseif inCombat then
        color = THREAT_COLORS.red
    else
        return nil, nil
    end
    
    return color, THREAT_ICON_PATHS.tank
end

-- Get threat color and icon for DPS/Healer
function ThreatIcon:GetDPSThreatVisuals(isTanking, status)
    local color, iconPath
    
    if isTanking then
        color = THREAT_COLORS.red
    elseif status and status >= 2 then
        color = THREAT_COLORS.orange
    elseif status and status >= 1 then
        color = THREAT_COLORS.yellow
    else
        return nil, nil
    end
    
    return color, THREAT_ICON_PATHS.aggro
end

-- Check if another tank has aggro
function ThreatIcon:OtherTankHasAggro(unit)
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local unitId = "raid" .. i
            if UnitExists(unitId) and not UnitIsUnit(unitId, "player") then
                local isTanking = UnitDetailedThreatSituation(unitId, unit)
                if isTanking then
                    return true
                end
            end
        end
    elseif self:IsInGroup() then
        for i = 1, GetNumPartyMembers() do
            local unitId = "party" .. i
            if UnitExists(unitId) then
                local isTanking = UnitDetailedThreatSituation(unitId, unit)
                if isTanking then
                    return true
                end
            end
        end
    end
    return false
end

-- Main update function (called by NotPlater)
function NotPlater:UpdateThreatIcon(frame)
    if not frame or not frame.threatIcon then return end
    
    -- Special handling for simulator
    if frame.simulatedTarget then
        local icon = frame.threatIcon.texture
        icon:SetTexture(THREAT_ICON_PATHS.aggro)
        icon:SetVertexColor(THREAT_COLORS.orange.r, THREAT_COLORS.orange.g, THREAT_COLORS.orange.b)
        frame.threatIcon.color = "orange"
        frame.threatIcon:Show()
        return
    end
    
    local config = self.db.profile.threatIcon
    
    -- Check if should show
    if not ThreatIcon:ShouldShowIcon(frame, config) then
        frame.threatIcon:Hide()
        return
    end
    
    -- Find unit for this nameplate
    local unit = frame.unit or ThreatIcon:FindUnitForNameplate(frame)
    
    -- Update cache if we have a unit
    if unit and UnitExists(unit) then
        frame.unit = unit
        local guid = UnitGUID(unit)
        if guid then
            frame.unitGUID = guid
            ThreatIcon:UpdateThreatCache(unit, guid)
        end
    end
    
    -- Check cached threat
    local hasCachedThreat = frame.unitGUID and threatStateCache[frame.unitGUID]
    
    if not unit and not hasCachedThreat then
        frame.threatIcon:Hide()
        return
    end
    
    -- Check if valid target
    if unit and UnitExists(unit) then
        local isPlayerOrPet = UnitIsPlayer(unit) or ThreatIcon:IsUnitPlayerPet(unit)
        if not (UnitCanAttack("player", unit) and not isPlayerOrPet) then
            frame.threatIcon:Hide()
            return
        end
    end
    
    -- Get threat visuals
    local mode = self.db.profile.threat.general.mode
    local icon = frame.threatIcon.texture
    local color, iconPath
    
    -- Store previous color for animation
    frame.threatIcon.colorPrev = frame.threatIcon.color
    
    if unit and UnitExists(unit) then
        -- Live threat data
        local isTanking, status = UnitDetailedThreatSituation("player", unit)
        
        if mode == "tank" then
            local otherTankHasAggro = ThreatIcon:OtherTankHasAggro(unit)
            local inCombat = UnitAffectingCombat(unit)
            color, iconPath = ThreatIcon:GetTankThreatVisuals(isTanking, otherTankHasAggro, inCombat)
        else
            color, iconPath = ThreatIcon:GetDPSThreatVisuals(isTanking, status)
        end
    elseif hasCachedThreat then
        -- Use cached threat data
        local cached = threatStateCache[frame.unitGUID]
        
        if mode == "tank" then
            if cached.isTanking then
                color = THREAT_COLORS.green
            else
                color = THREAT_COLORS.red
            end
            iconPath = THREAT_ICON_PATHS.tank
        else
            if cached.isTanking then
                color = THREAT_COLORS.red
            elseif cached.status and cached.status >= 2 then
                color = THREAT_COLORS.orange
            elseif cached.status and cached.status >= 1 then
                color = THREAT_COLORS.yellow
            end
            iconPath = THREAT_ICON_PATHS.aggro
        end
    end
    
    -- Apply visuals
    if color and iconPath then
        icon:SetTexture(iconPath)
        icon:SetVertexColor(color.r, color.g, color.b)
        frame.threatIcon.color = color == THREAT_COLORS.green and "green" or
                                 color == THREAT_COLORS.blue and "blue" or
                                 color == THREAT_COLORS.yellow and "yellow" or
                                 color == THREAT_COLORS.orange and "orange" or "red"
        
        -- Trigger fade-in animation on color change
        if frame.threatIcon.colorPrev ~= frame.threatIcon.color then
            frame.threatIcon:SetAlpha(0)
            frame.threatIcon.fadeIn = true
        end
        
        frame.threatIcon:Show()
    else
        frame.threatIcon:Hide()
    end
    
    -- Apply opacity
    if not frame.threatIcon.fadeIn then
        frame.threatIcon:SetAlpha(config.general.opacity or 1)
    end
end

-- Construct threat icon frame
function NotPlater:ConstructThreatIcon(frame)
    if frame.threatIcon then return end
    
    frame.threatIcon = CreateFrame("Frame", nil, frame)
    frame.threatIcon:SetFrameLevel(frame:GetFrameLevel() + 3)
    
    frame.threatIcon.texture = frame.threatIcon:CreateTexture(nil, "OVERLAY")
    frame.threatIcon.texture:SetAllPoints()
    
    -- Animation variables
    frame.threatIcon.fadeIn = false
    frame.threatIcon.fadeAlpha = 0
    
    frame.threatIcon:Hide()
    
    -- OnShow handler
    frame.threatIcon:SetScript("OnShow", function(self)
        self.fadeIn = true
        self.fadeAlpha = 0
        self:SetAlpha(0)
    end)
    
    -- OnUpdate for fade animation
    frame.threatIcon:SetScript("OnUpdate", function(self, elapsed)
        if self.fadeIn then
            self.fadeAlpha = self.fadeAlpha + (elapsed * 4)
            if self.fadeAlpha >= 1 then
                self.fadeAlpha = 1
                self.fadeIn = false
            end
            local config = NotPlater.db.profile.threatIcon
            local targetOpacity = (config and config.general and config.general.opacity) or 1
            self:SetAlpha(self.fadeAlpha * targetOpacity)
        end
    end)
end

-- Configure threat icon
function NotPlater:ConfigureThreatIcon(frame)
    if not frame.threatIcon then return end
    
    local config = self.db.profile.threatIcon
    if not config then return end
    
    self:SetSize(frame.threatIcon, config.size.width or 36, config.size.height or 36)
    
    frame.threatIcon:ClearAllPoints()
    local anchor = config.position.anchor or "RIGHT"
    local xOffset = config.position.xOffset or -32
    local yOffset = config.position.yOffset or 0
    
    if frame.healthBar then
        frame.threatIcon:SetPoint(anchor, frame.healthBar, anchor, xOffset, yOffset)
    else
        frame.threatIcon:SetPoint(anchor, frame, anchor, xOffset, yOffset)
    end
    
    frame.threatIcon:SetAlpha(config.general.opacity or 1)
end

-- Scale threat icon
function NotPlater:ScaleThreatIcon(frame, isTarget)
    if not frame.threatIcon then return end
    
    local scaleConfig = self.db.profile.target.general.scale
    if scaleConfig and scaleConfig.threatIcon then
        local config = self.db.profile.threatIcon
        local scalingFactor = isTarget and scaleConfig.scalingFactor or 1
        self:SetSize(frame.threatIcon, 
            (config.size.width or 36) * scalingFactor, 
            (config.size.height or 36) * scalingFactor
        )
    end
end