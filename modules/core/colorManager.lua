-- modules/core/colorManager.lua
-- Centralized nameplate color management system

if not NotPlater then return end

local ColorManager = {}
NotPlater.ColorManager = ColorManager

-- Local references for performance
local UnitSelectionColor = UnitSelectionColor
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Color provider registry
local colorProviders = {}
local providerPriorities = {}

-- Initialize the color manager
function ColorManager:Initialize()
    -- Register default providers
    self:RegisterDefaultProviders()
end

-- Register a color provider
function ColorManager:RegisterColorProvider(name, priority, providerFunc)
    colorProviders[name] = providerFunc
    
    -- Insert into priority list
    table.insert(providerPriorities, {
        name = name,
        priority = priority,
        func = providerFunc
    })
    
    -- Sort by priority (lower number = higher priority)
    table.sort(providerPriorities, function(a, b)
        return a.priority < b.priority
    end)
end

-- Unregister a color provider
function ColorManager:UnregisterColorProvider(name)
    colorProviders[name] = nil
    
    -- Remove from priority list
    for i = #providerPriorities, 1, -1 do
        if providerPriorities[i].name == name then
            table.remove(providerPriorities, i)
            break
        end
    end
end

-- Get nameplate color with priority system
function ColorManager:GetNameplateColor(frame, playerName)
    if not frame or not playerName then
        return nil, nil
    end
    
    -- Check if colored nameplates are enabled
    if not NotPlater.db.profile.threat.general.useColoredThreatNameplates then
        -- Return class color if available and enabled
        if NotPlater.db.profile.threat.nameplateColors.general.useClassColors then
            local color, colorType = self:GetClassColorFromAllSources(frame, playerName)
            if color then
                return color, colorType
            end
        end
        -- Return default reaction color
        return self:GetDefaultColor(frame)
    end
    
    -- Check each provider in priority order
    for _, provider in ipairs(providerPriorities) do
        local color, colorType = provider.func(frame, playerName)
        if color then
            return color, colorType
        end
    end
    
    -- Fallback to default color
    return self:GetDefaultColor(frame)
end

-- Get class color from all cache sources
function ColorManager:GetClassColorFromAllSources(frame, playerName)
    if not playerName then return nil, nil end
    
    -- Check if class colors are enabled
    if not NotPlater.db.profile.threat.nameplateColors.general.useClassColors then
        return nil, nil
    end
    
    -- Check if we should skip NPCs
    local skipNPCs = NotPlater.db.profile.threat.nameplateColors.general.playersOnly
    
    -- Priority order: Party/Raid > Guild > RecentlySeen > Direct detection
    
    -- 1. Party/Raid Cache
    if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.GetMemberData then
        local memberData = NotPlater.PartyRaidCache:GetMemberData(playerName)
        if memberData and memberData.classColor then
            if not skipNPCs or memberData.isPlayer ~= false then
                return memberData.classColor, "party_raid"
            end
        end
    end
    
    -- 2. Guild Cache
    if NotPlater.GuildCache and NotPlater.GuildCache.GetMemberData then
        local memberData = NotPlater.GuildCache:GetMemberData(playerName)
        if memberData and memberData.classColor then
            if not skipNPCs or memberData.isPlayer ~= false then
                return memberData.classColor, "guild"
            end
        end
    end
    
    -- 3. Recently Seen Cache
    if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.GetPlayerData then
        local data = NotPlater.RecentlySeenCache:GetPlayerData(playerName)
        if data and data.classColor then
            if not skipNPCs or data.isPlayer ~= false then
                -- Create a copy to avoid reference issues
                local colorCopy = {
                    r = data.classColor.r,
                    g = data.classColor.g,
                    b = data.classColor.b
                }
                return colorCopy, "recently_seen"
            end
        end
    end
    
    -- 4. Direct unit detection (if frame has unit association)
    if frame.unit and UnitExists(frame.unit) then
        if not skipNPCs or UnitIsPlayer(frame.unit) then
            local _, classFileName = UnitClass(frame.unit)
            if classFileName and RAID_CLASS_COLORS[classFileName] then
                return RAID_CLASS_COLORS[classFileName], "direct"
            end
        end
    end
    
    return nil, nil
end

-- Get default color based on unit reaction
function ColorManager:GetDefaultColor(frame)
    -- Try to get reaction color
    if frame.unit and UnitExists(frame.unit) then
        local r, g, b = UnitSelectionColor(frame.unit)
        if r and g and b then
            return {r = r, g = g, b = b}, "reaction"
        end
    end
    
    -- Fallback to config default
    local healthBarConfig = NotPlater.db.profile.healthBar
    if healthBarConfig and healthBarConfig.statusBar and healthBarConfig.statusBar.general then
        local color = healthBarConfig.statusBar.general.color
        return {
            r = color[1],
            g = color[2],
            b = color[3]
        }, "default"
    end
    
    -- Ultimate fallback
    return {r = 0.5, g = 0.5, b = 1}, "fallback"
end

-- Apply color to nameplate
function ColorManager:ApplyNameplateColor(frame, color, colorType)
    if not frame or not frame.healthBar or not color then
        return false
    end
    
    -- Ensure color has valid RGB values
    if not color.r or not color.g or not color.b then
        return false
    end
    
    -- Apply to health bar
    frame.healthBar:SetStatusBarColor(color.r, color.g, color.b, 1)
    
    -- Store color info on frame
    frame.currentColor = color
    frame.currentColorType = colorType
    
    -- Also store as unitClass for compatibility
    if colorType and (colorType == "party_raid" or colorType == "guild" or 
                      colorType == "recently_seen" or colorType == "direct") then
        frame.unitClass = color
        frame.unitClassFromCache = true
    end
    
    return true
end

-- Register default color providers
function ColorManager:RegisterDefaultProviders()
    -- 1. Threat-based colors (highest priority when in combat)
    self:RegisterColorProvider("threat", 10, function(frame, playerName)
        -- Only apply threat colors if in combat and threat coloring is enabled
        if not UnitAffectingCombat("player") then
            return nil, nil
        end
        
        if not NotPlater.db.profile.threat.general.useColoredThreatNameplates then
            return nil, nil
        end
        
        -- Let threat module handle this
        if NotPlater.ThreatProvider then
            return NotPlater.ThreatProvider:GetThreatColor(frame)
        end
        
        return nil, nil
    end)
    
    -- 2. Class colors (second priority)
    self:RegisterColorProvider("class", 20, function(frame, playerName)
        return self:GetClassColorFromAllSources(frame, playerName)
    end)
    
    -- 3. Reaction colors (third priority)
    self:RegisterColorProvider("reaction", 30, function(frame, playerName)
        if frame.unit and UnitExists(frame.unit) then
            local r, g, b = UnitSelectionColor(frame.unit)
            if r and g and b then
                return {r = r, g = g, b = b}, "reaction"
            end
        end
        return nil, nil
    end)
    
    -- 4. Default colors (lowest priority)
    self:RegisterColorProvider("default", 100, function(frame, playerName)
        return self:GetDefaultColor(frame)
    end)
end

-- Update nameplate appearance (main entry point)
function ColorManager:UpdateNameplateAppearance(frame)
    if not frame then return end
    
    -- Get player name from nameplate
    local nameText = select(7, frame:GetRegions())
    local playerName = nameText and nameText:GetText()
    
    -- Get and apply color
    local color, colorType = self:GetNameplateColor(frame, playerName)
    if color then
        self:ApplyNameplateColor(frame, color, colorType)
    end
    
    -- Update other visual components
    if NotPlater.UpdateThreatIcon then
        NotPlater:UpdateThreatIcon(frame)
    end
end

-- Clear cached color data from frame
function ColorManager:ClearFrameColorCache(frame)
    if not frame then return end
    
    frame.currentColor = nil
    frame.currentColorType = nil
    frame.unitClass = nil
    frame.unitClassFromCache = nil
    frame.lastCheckedName = nil
end