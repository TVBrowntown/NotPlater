-- modules/threat-icon-3.3.5.lua
-- Fixed version with proper GUID matching to prevent threat icons on wrong nameplates
-- For WotLK 3.3.5

if not NotPlater then return end

local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitIsPlayer = UnitIsPlayer
local UnitCreatureType = UnitCreatureType
local UnitName = UnitName
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
    green = {r = 0, g = 1, b = 0},      -- Safe/Tanking properly
    blue = {r = 0, g = 0.75, b = 1},    -- Other tank has aggro
    yellow = {r = 1, g = 0.90, b = 0},  -- Warning (50-75% threat)
    orange = {r = 1, g = 0.5, b = 0},   -- High threat (75-100%)
    red = {r = 1, g = 0, b = 0}         -- Has aggro/Lost aggro
}

-- Cache for tracking threat state per GUID
local threatStateCache = {}

-- Custom function to detect if unit is a player's pet for WotLK 3.3.5
local function IsUnitPlayerPet(unit)
    if not unit or not UnitExists(unit) then return false end
    
    -- Check if it's player controlled and not a player
    if not UnitPlayerControlled(unit) or UnitIsPlayer(unit) then
        return false
    end
    
    -- Get the unit's name
    local unitName = UnitName(unit)
    if not unitName then return false end
    
    -- Check for common pet/minion patterns in the name
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
    
    -- Check creature type for demons and elementals (warlock/mage pets)
    local creatureType = UnitCreatureType(unit)
    if creatureType and (creatureType == "Demon" or creatureType == "Elemental") and UnitPlayerControlled(unit) then
        return true
    end
    
    -- Check if it's a hunter pet by checking for Beast type and player control
    if creatureType == "Beast" and UnitPlayerControlled(unit) then
        return true
    end
    
    return false
end

-- Helper function to check if we're in a group
local function IsInGroup()
    return GetNumPartyMembers() > 0
end

-- Helper function to check if we're in a raid
local function IsInRaid()
    return GetNumRaidMembers() > 0
end

-- Try to find a unit ID for this nameplate AND verify it matches
function NotPlater:FindAndVerifyUnitForNameplate(frame)
    if not frame then return nil, nil end
    
    -- Get name and level from nameplate
    local nameText, levelText = select(7, frame:GetRegions())
    if not nameText or not levelText then return nil, nil end
    
    local name = nameText:GetText()
    local level = levelText:GetText()
    if not name or not level then return nil, nil end
    
    -- Check all possible unit IDs
    local unitsToCheck = {"target", "mouseover", "focus"}
    
    -- Add party/raid targets
    if IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            table.insert(unitsToCheck, "raid" .. i .. "-target")
        end
    elseif IsInGroup() then
        for i = 1, GetNumPartyMembers() do
            table.insert(unitsToCheck, "party" .. i .. "-target")
        end
    end
    
    -- Check each unit
    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) and 
           name == UnitName(unit) and 
           level == tostring(UnitLevel(unit)) then
            -- Found a match - get the GUID
            local guid = UnitGUID(unit)
            if guid then
                -- Store the GUID on the frame
                frame.unitGUID = guid
                frame.unit = unit
                return unit, guid
            end
        end
    end
    
    return nil, nil
end

function NotPlater:UpdateThreatIcon(frame)
    if not frame or not frame.threatIcon then return end
    
    -- Special handling for simulator frame
    if frame.simulatedTarget then
        -- Always show threat icon in simulator for testing
        local icon = frame.threatIcon.texture
        icon:SetTexture(THREAT_ICON_PATHS.aggro)
        icon:SetVertexColor(THREAT_COLORS.orange.r, THREAT_COLORS.orange.g, THREAT_COLORS.orange.b)
        frame.threatIcon.color = "orange"
        frame.threatIcon:Show()
        return
    end
    
    -- Try to find and verify unit for this specific nameplate
    local unit, guid = self:FindAndVerifyUnitForNameplate(frame)
    
    -- CRITICAL: Only proceed if we found a unit AND its GUID matches this nameplate
    if not unit or not guid then
        -- No matching unit found - hide the icon
        frame.threatIcon:Hide()
        return
    end
    
    -- CRITICAL: Verify the nameplate still represents this unit
    -- This prevents showing threat icons on wrong nameplates
    if frame.unitGUID and frame.unitGUID ~= guid then
        -- GUID mismatch - this nameplate doesn't represent the unit we found
        frame.threatIcon:Hide()
        return
    end
    
    -- Update the cache for this specific GUID
    local isTanking, status = UnitDetailedThreatSituation("player", unit)
    if isTanking or (status and status > 0) then
        threatStateCache[guid] = {
            isTanking = isTanking,
            status = status,
            timestamp = GetTime(),
            unitName = UnitName(unit)
        }
    elseif threatStateCache[guid] then
        -- No threat anymore - clear from cache
        threatStateCache[guid] = nil
    end
    
    local threatIconConfig = self.db.profile.threatIcon
    
    -- Check if threat icon is enabled
    if not threatIconConfig or not threatIconConfig.general or not threatIconConfig.general.enable then
        frame.threatIcon:Hide()
        return
    end
    
    -- Determine visibility mode
    local showIcon = false
    if threatIconConfig.general.visibility == "always" then
        showIcon = true
    elseif threatIconConfig.general.visibility == "combat" then
        showIcon = UnitAffectingCombat("player")
    elseif threatIconConfig.general.visibility == "group" then
        showIcon = (IsInRaid() or IsInGroup())
    end
    
    if not showIcon then
        frame.threatIcon:Hide()
        return
    end
    
    -- Check if this is an attackable NPC
    local isPlayerOrPet = UnitIsPlayer(unit) or IsUnitPlayerPet(unit)
    if not (UnitCanAttack("player", unit) and not isPlayerOrPet) then
        frame.threatIcon:Hide()
        return
    end
    
    local mode = self.db.profile.threat.general.mode
    local icon = frame.threatIcon.texture
    
    -- Store previous color for animation triggers
    frame.threatIcon.colorPrev = frame.threatIcon.color
    
    -- Update threat icon based on mode
    if mode == "tank" then
        self:UpdateTankThreatIcon(frame, unit, icon)
    else
        self:UpdateDPSThreatIcon(frame, unit, icon)
    end
    
    -- Trigger animation on color change (simple fade-in for 3.3.5)
    if frame.threatIcon.colorPrev ~= frame.threatIcon.color then
        frame.threatIcon:SetAlpha(0)
        frame.threatIcon.fadeIn = true
    end
    
    -- Apply opacity setting
    local targetOpacity = threatIconConfig.general.opacity or 1
    if not frame.threatIcon.fadeIn then
        frame.threatIcon:SetAlpha(targetOpacity)
    end
end

function NotPlater:UpdateTankThreatIcon(frame, unit, icon)
    local iAmTanking = UnitDetailedThreatSituation("player", unit)
    
    -- Set tank icon
    icon:SetTexture(THREAT_ICON_PATHS.tank)
    
    -- Check if another tank has aggro
    local function otherTankHasAggro()
        -- Check raid members
        if IsInRaid() then
            for i = 1, GetNumRaidMembers() do
                local unitId = "raid" .. i
                if UnitExists(unitId) and not UnitIsUnit(unitId, "player") then
                    local isTanking = UnitDetailedThreatSituation(unitId, unit)
                    if isTanking then
                        return true
                    end
                end
            end
        -- Check party members
        elseif IsInGroup() then
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
    
    if iAmTanking then
        -- I have aggro - good for tank
        icon:SetVertexColor(THREAT_COLORS.green.r, THREAT_COLORS.green.g, THREAT_COLORS.green.b)
        frame.threatIcon.color = "green"
        frame.threatIcon:Show()
    elseif otherTankHasAggro() then
        -- Another tank has aggro - acceptable
        icon:SetVertexColor(THREAT_COLORS.blue.r, THREAT_COLORS.blue.g, THREAT_COLORS.blue.b)
        frame.threatIcon.color = "blue"
        frame.threatIcon:Show()
    elseif UnitAffectingCombat(unit) then
        -- No tank has aggro - bad
        icon:SetVertexColor(THREAT_COLORS.red.r, THREAT_COLORS.red.g, THREAT_COLORS.red.b)
        frame.threatIcon.color = "red"
        frame.threatIcon:Show()
    else
        frame.threatIcon:Hide()
    end
end

function NotPlater:UpdateDPSThreatIcon(frame, unit, icon)
    -- For 3.3.5, we use UnitDetailedThreatSituation
    local isTanking, status = UnitDetailedThreatSituation("player", unit)
    
    -- Set aggro icon
    icon:SetTexture(THREAT_ICON_PATHS.aggro)
    
    if isTanking then
        -- Has aggro - bad for DPS
        icon:SetVertexColor(THREAT_COLORS.red.r, THREAT_COLORS.red.g, THREAT_COLORS.red.b)
        frame.threatIcon.color = "red"
        frame.threatIcon:Show()
    elseif status and status >= 2 then
        -- High threat warning
        icon:SetVertexColor(THREAT_COLORS.orange.r, THREAT_COLORS.orange.g, THREAT_COLORS.orange.b)
        frame.threatIcon.color = "orange"
        frame.threatIcon:Show()
    elseif status and status >= 1 then
        -- Medium threat warning
        icon:SetVertexColor(THREAT_COLORS.yellow.r, THREAT_COLORS.yellow.g, THREAT_COLORS.yellow.b)
        frame.threatIcon.color = "yellow"
        frame.threatIcon:Show()
    else
        -- Low/no threat - hide icon
        frame.threatIcon:Hide()
    end
end

-- Rest of the functions remain the same...
function NotPlater:ConstructThreatIcon(frame)
    if frame.threatIcon then return end
    
    -- Create threat icon frame
    frame.threatIcon = CreateFrame("Frame", nil, frame)
    frame.threatIcon:SetFrameLevel(frame:GetFrameLevel() + 3)
    
    -- Create icon texture
    frame.threatIcon.texture = frame.threatIcon:CreateTexture(nil, "OVERLAY")
    frame.threatIcon.texture:SetAllPoints()
    
    -- Simple fade-in animation for 3.3.5 (manual implementation)
    frame.threatIcon.fadeIn = false
    frame.threatIcon.fadeAlpha = 0
    
    -- Hide by default
    frame.threatIcon:Hide()
    
    -- OnShow script for simple fade-in
    frame.threatIcon:SetScript("OnShow", function(self)
        self.fadeIn = true
        self.fadeAlpha = 0
        self:SetAlpha(0)
    end)
    
    -- OnUpdate script for manual fade-in animation
    frame.threatIcon:SetScript("OnUpdate", function(self, elapsed)
        if self.fadeIn then
            self.fadeAlpha = self.fadeAlpha + (elapsed * 4) -- 0.25 second fade-in
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

function NotPlater:ConfigureThreatIcon(frame)
    if not frame.threatIcon then return end
    
    local config = self.db.profile.threatIcon
    if not config then return end
    
    -- Set size
    self:SetSize(frame.threatIcon, config.size.width or 36, config.size.height or 36)
    
    -- Set position
    frame.threatIcon:ClearAllPoints()
    local anchor = config.position.anchor or "RIGHT"
    local xOffset = config.position.xOffset or -32
    local yOffset = config.position.yOffset or 0
    
    -- Position relative to health bar
    if frame.healthBar then
        frame.threatIcon:SetPoint(anchor, frame.healthBar, anchor, xOffset, yOffset)
    else
        frame.threatIcon:SetPoint(anchor, frame, anchor, xOffset, yOffset)
    end
    
    -- Set opacity
    frame.threatIcon:SetAlpha(config.general.opacity or 1)
end

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

-- Clean up old threat cache entries (call periodically)
function NotPlater:CleanThreatCache()
    local currentTime = GetTime()
    for guid, data in pairs(threatStateCache) do
        -- Remove entries older than 10 seconds
        if currentTime - data.timestamp > 10 then
            threatStateCache[guid] = nil
        end
    end
end

-- Add a periodic cleaner
local cleanupFrame = CreateFrame("Frame")
cleanupFrame.elapsed = 0
cleanupFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 5 then -- Clean every 5 seconds
        self.elapsed = 0
        NotPlater:CleanThreatCache()
    end
end)