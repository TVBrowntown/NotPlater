-- modules/core/colorManager.lua
-- Centralized nameplate color management system

if not NotPlater then return end

local ColorManager = {}
NotPlater.ColorManager = ColorManager

-- Local references for performance
local UnitSelectionColor = UnitSelectionColor
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitPlayerControlled = UnitPlayerControlled
local UnitCreatureType = UnitCreatureType
local UnitName = UnitName
local UnitClass = UnitClass
local UnitReaction = UnitReaction
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Initialize the color manager
function ColorManager:Initialize()
    -- Color manager is ready
end

-- Try to find unit ID for a nameplate by name matching
function ColorManager:FindUnitForNameplate(frame, playerName)
    if not frame or not playerName then
        return nil
    end
    
    -- Get level for more accurate matching
    local levelText = select(8, frame:GetRegions())
    local level = levelText and levelText:GetText()
    
    -- Check common units
    local unitsToCheck = {"target", "mouseover", "pet", "focus"}
    
    -- Add party members
    if UnitInParty("player") then
        for i = 1, GetNumPartyMembers() do
            table.insert(unitsToCheck, "party" .. i)
            table.insert(unitsToCheck, "partypet" .. i)
        end
    end
    
    -- Add raid members  
    if UnitInRaid("player") then
        for i = 1, GetNumRaidMembers() do
            table.insert(unitsToCheck, "raid" .. i)
            table.insert(unitsToCheck, "raidpet" .. i)
        end
    end
    
    -- Find matching unit
    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) and UnitName(unit) == playerName then
            -- Additional level check if available
            if not level or level == tostring(UnitLevel(unit)) then
                -- Store this unit info on the frame for future use
                self:StoreUnitInfoOnFrame(frame, unit, playerName)
                return unit
            end
        end
    end
    
    return nil
end

-- Check if unit should have nameplate shown based on filters
function ColorManager:ShouldShowNameplate(frame, playerName)
    local filters = NotPlater.db.profile.healthBar.unitFilters
    if not filters then
        return true -- Default to showing if no filters configured
    end
    
    -- Try to find unit if not provided
    local unit = nil
    if playerName then
        unit = self:FindUnitForNameplate(frame, playerName)
    end
    
    -- If we can't find a unit, default to showing
    if not unit or not UnitExists(unit) then
        return true
    end
    
    -- Check if it's a totem
    if self:IsTotem(unit) then
        -- Check if it's our own totem
        if self:IsOwnUnit(unit) then
            return filters.showOwnTotems
        else
            -- Other player's totem
            return filters.showPlayerTotems
        end
    end
    
    -- Check if it's a pet/minion
    if self:IsPetOrMinion(unit) then
        -- Check if it's our own pet
        if self:IsOwnUnit(unit) or UnitIsUnit(unit, "pet") then
            return filters.showOwnPet
        else
            -- Other player's pet
            return filters.showOtherPlayerPets
        end
    end
    
    -- Default to showing for other units (players, NPCs, etc.)
    return true
end

-- Check if unit is a totem
function ColorManager:IsTotem(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    
    local creatureType = UnitCreatureType(unit)
    if creatureType == "Totem" then
        return true
    end
    
    -- Additional totem detection based on name patterns
    local name = UnitName(unit)
    if name then
        -- Common totem names (can be expanded)
        local totemPatterns = {
            "Totem", "Earthbind", "Searing", "Healing Stream", "Mana Spring",
            "Fire Nova", "Magma", "Stoneclaw", "Stoneskin", "Strength of Earth",
            "Grace of Air", "Windfury", "Grounding", "Tremor", "Poison Cleansing",
            "Disease Cleansing", "Fire Resistance", "Frost Resistance", "Nature Resistance",
            "Flametongue", "Frostbrand", "Rockbiter", "Windfury Totem"
        }
        
        for _, pattern in ipairs(totemPatterns) do
            if string.find(name, pattern) then
                return true
            end
        end
    end
    
    return false
end

-- Check if unit is a pet or minion
function ColorManager:IsPetOrMinion(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    
    -- Check if it's player controlled but not a player
    if UnitPlayerControlled(unit) and not UnitIsPlayer(unit) then
        local creatureType = UnitCreatureType(unit)
        if creatureType then
            -- Common pet/minion creature types
            if creatureType == "Beast" or creatureType == "Demon" or 
               creatureType == "Elemental" or creatureType == "Undead" then
                return true
            end
        end
        
        -- Check name patterns for pets/minions
        local name = UnitName(unit)
        if name then
            local petPatterns = {
                "Pet", "Minion", "Ghoul", "Imp", "Voidwalker", "Succubus", 
                "Felhunter", "Felguard", "Water Elemental", "Mirror Image",
                "Shadowfiend", "Spirit Wolf", "Army of the Dead"
            }
            
            for _, pattern in ipairs(petPatterns) do
                if string.find(name, pattern) then
                    return true
                end
            end
        end
        
        return true -- Assume player controlled non-players are pets
    end
    
    return false
end

-- Check if unit belongs to the player
function ColorManager:IsOwnUnit(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    
    -- Direct ownership check
    if UnitIsUnit(unit, "pet") then
        return true
    end
    
    -- Check for player totems (they usually have player name in them or special detection)
    local name = UnitName(unit)
    local playerName = UnitName("player")
    
    if name and playerName then
        -- Some totems might have player name
        if string.find(name, playerName) then
            return true
        end
    end
    
    -- For totems, we might need to use different detection methods
    -- This is a simplified approach - in practice, totem ownership detection
    -- can be more complex and might require additional addon APIs
    
    return false
end

-- Store unit information on frame for persistence
function ColorManager:StoreUnitInfoOnFrame(frame, unit, playerName)
    if not frame or not unit or not UnitExists(unit) then
        return
    end
    
    -- Store basic unit info
    frame.cachedUnitInfo = {
        name = playerName or UnitName(unit),
        level = UnitLevel(unit),
        isPlayer = UnitIsPlayer(unit),
        reaction = UnitReaction(unit, "player"),
        lastUpdate = GetTime(),
        unitType = unit
    }
    
    -- Store class info if it's a player
    if UnitIsPlayer(unit) then
        local className, classFileName = UnitClass(unit)
        if classFileName then
            frame.cachedUnitInfo.className = className
            frame.cachedUnitInfo.classFileName = classFileName
            frame.cachedUnitInfo.classColor = RAID_CLASS_COLORS[classFileName]
        end
    end
    
    -- Store pet/ownership info
    frame.cachedUnitInfo.isPet = UnitIsUnit(unit, "pet")
    frame.cachedUnitInfo.isOwnUnit = self:IsOwnUnit(unit)
    frame.cachedUnitInfo.isTotem = self:IsTotem(unit)
    frame.cachedUnitInfo.isPetOrMinion = self:IsPetOrMinion(unit)
end

-- Get cached unit info from frame
function ColorManager:GetCachedUnitInfo(frame)
    if not frame or not frame.cachedUnitInfo then
        return nil
    end
    
    -- Check if cache is still relatively fresh (within 30 seconds)
    local currentTime = GetTime()
    if currentTime - frame.cachedUnitInfo.lastUpdate > 30 then
        return nil
    end
    
    return frame.cachedUnitInfo
end

-- Get nameplate color based on new system
function ColorManager:GetNameplateColor(frame, playerName, unit)
    if not frame then
        return nil, nil
    end
    
    local coloringSystem = NotPlater.db.profile.healthBar.coloring.system
    
    if coloringSystem == "class" then
        -- Use class color system
        return self:GetClassColorFromAllSources(frame, playerName, unit)
    else
        -- Use reaction color system (default)
        return self:GetReactionColor(frame, unit)
    end
end

-- Get class color from all cache sources and direct detection
function ColorManager:GetClassColorFromAllSources(frame, playerName, unit)
    if not NotPlater.db.profile.healthBar.coloring.classColors.enable then
        return self:GetReactionColor(frame, unit) -- Fallback to reaction colors
    end
    
    -- Check if we should skip NPCs
    local playersOnly = NotPlater.db.profile.healthBar.coloring.classColors.playersOnly
    
    -- Priority order: Cached info > Party/Raid > Guild > RecentlySeen > Direct detection
    
    -- 0. Check cached unit info first
    local cachedInfo = self:GetCachedUnitInfo(frame)
    if cachedInfo and cachedInfo.classColor and cachedInfo.isPlayer then
        if not playersOnly or cachedInfo.isPlayer then
            return cachedInfo.classColor, "cached"
        end
    end
    
    -- 1. Party/Raid Cache
    if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.GetMemberData then
        local memberData = NotPlater.PartyRaidCache:GetMemberData(playerName)
        if memberData and memberData.classColor then
            if not playersOnly or memberData.isPlayer ~= false then
                return memberData.classColor, "party_raid"
            end
        end
    end
    
    -- 2. Guild Cache
    if NotPlater.GuildCache and NotPlater.GuildCache.GetMemberData then
        local memberData = NotPlater.GuildCache:GetMemberData(playerName)
        if memberData and memberData.classColor then
            if not playersOnly or memberData.isPlayer ~= false then
                return memberData.classColor, "guild"
            end
        end
    end
    
    -- 3. Recently Seen Cache
    if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.GetPlayerData then
        local data = NotPlater.RecentlySeenCache:GetPlayerData(playerName)
        if data and data.classColor then
            if not playersOnly or data.isPlayer ~= false then
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
    
    -- 4. Direct unit detection
    if unit and UnitExists(unit) then
        if not playersOnly or UnitIsPlayer(unit) then
            local _, classFileName = UnitClass(unit)
            if classFileName and RAID_CLASS_COLORS[classFileName] then
                -- Store this info for future use
                self:StoreUnitInfoOnFrame(frame, unit, playerName)
                
                -- Add to recently seen cache if it's a player
                if UnitIsPlayer(unit) and NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.AddPlayer then
                    local className = UnitClass(unit)
                    local level = UnitLevel(unit)
                    NotPlater.RecentlySeenCache:AddPlayer(playerName, className, classFileName, level)
                end
                
                return RAID_CLASS_COLORS[classFileName], "direct"
            end
        end
    end
    
    -- 5. Check target/mouseover if no unit provided
    if not unit and playerName then
        -- Try to find the unit using our improved detection
        unit = self:FindUnitForNameplate(frame, playerName)
        
        if unit and UnitExists(unit) then
            if not playersOnly or UnitIsPlayer(unit) then
                local _, classFileName = UnitClass(unit)
                if classFileName and RAID_CLASS_COLORS[classFileName] then
                    -- Add to recently seen cache if it's a player
                    if UnitIsPlayer(unit) and NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.AddPlayer then
                        local className = UnitClass(unit)
                        local level = UnitLevel(unit)
                        NotPlater.RecentlySeenCache:AddPlayer(playerName, className, classFileName, level)
                    end
                    
                    return RAID_CLASS_COLORS[classFileName], "found_unit"
                end
            end
        end
        
        -- Fallback to individual unit checks
        -- Check target
        if UnitExists("target") and playerName == UnitName("target") then
            if not playersOnly or UnitIsPlayer("target") then
                local _, classFileName = UnitClass("target")
                if classFileName and RAID_CLASS_COLORS[classFileName] then
                    -- Store this info
                    self:StoreUnitInfoOnFrame(frame, "target", playerName)
                    
                    -- Add to recently seen cache
                    if UnitIsPlayer("target") and NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.AddPlayer then
                        local className = UnitClass("target")
                        local level = UnitLevel("target")
                        NotPlater.RecentlySeenCache:AddPlayer(playerName, className, classFileName, level)
                    end
                    
                    return RAID_CLASS_COLORS[classFileName], "target"
                end
            end
        end
        
        -- Check mouseover
        if UnitExists("mouseover") and playerName == UnitName("mouseover") then
            if not playersOnly or UnitIsPlayer("mouseover") then
                local _, classFileName = UnitClass("mouseover")
                if classFileName and RAID_CLASS_COLORS[classFileName] then
                    -- Store this info
                    self:StoreUnitInfoOnFrame(frame, "mouseover", playerName)
                    
                    -- Add to recently seen cache
                    if UnitIsPlayer("mouseover") and NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.AddPlayer then
                        local className = UnitClass("mouseover")
                        local level = UnitLevel("mouseover")
                        NotPlater.RecentlySeenCache:AddPlayer(playerName, className, classFileName, level)
                    end
                    
                    return RAID_CLASS_COLORS[classFileName], "mouseover"
                end
            end
        end
    end
    
    -- Fallback to reaction colors
    return self:GetReactionColor(frame, unit)
end

-- Get reaction-based color
function ColorManager:GetReactionColor(frame, unit)
    local reactionColors = NotPlater.db.profile.healthBar.coloring.reactionColors
    
    -- Get player name for unit resolution if no unit provided
    local playerName = nil
    if frame then
        local nameText = select(7, frame:GetRegions())
        playerName = nameText and nameText:GetText()
    end
    
    -- Try to find unit if not provided
    if not unit and playerName then
        unit = self:FindUnitForNameplate(frame, playerName)
    end
    
    if unit and UnitExists(unit) then
        -- Special handling for player's own units (pets, totems)
        if self:IsOwnUnit(unit) or UnitIsUnit(unit, "pet") then
            return reactionColors.friendly, "own_unit"
        end
        
        local reaction = UnitReaction(unit, "player")
        
        if reaction then
            if reaction <= 2 then
                -- Hostile
                return reactionColors.hostile, "hostile"
            elseif reaction == 4 then
                -- Neutral
                return reactionColors.neutral, "neutral"
            elseif reaction >= 5 then
                -- Friendly
                return reactionColors.friendly, "friendly"
            end
        end
        
        -- Fallback to UnitSelectionColor if reaction detection fails
        local r, g, b = UnitSelectionColor(unit)
        if r and g and b then
            return {r = r, g = g, b = b}, "selection"
        end
    end
    
    -- Try to get reaction from common units if no unit provided
    if not unit and playerName then
        -- Check target
        if UnitExists("target") and playerName == UnitName("target") then
            if UnitIsUnit("target", "pet") then
                return reactionColors.friendly, "own_pet"
            end
            local reaction = UnitReaction("target", "player")
            if reaction then
                if reaction <= 2 then
                    return reactionColors.hostile, "hostile"
                elseif reaction == 4 then
                    return reactionColors.neutral, "neutral"
                elseif reaction >= 5 then
                    return reactionColors.friendly, "friendly"
                end
            end
        end
        
        -- Check mouseover
        if UnitExists("mouseover") and playerName == UnitName("mouseover") then
            if UnitIsUnit("mouseover", "pet") then
                return reactionColors.friendly, "own_pet"
            end
            local reaction = UnitReaction("mouseover", "player")
            if reaction then
                if reaction <= 2 then
                    return reactionColors.hostile, "hostile"
                elseif reaction == 4 then
                    return reactionColors.neutral, "neutral"
                elseif reaction >= 5 then
                    return reactionColors.friendly, "friendly"
                end
            end
        end
        
        -- Check pet specifically
        if UnitExists("pet") and playerName == UnitName("pet") then
            return reactionColors.friendly, "own_pet"
        end
    end
    
    -- Ultimate fallback - neutral yellow for unknown units
    return reactionColors.neutral, "fallback"
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
    frame.healthBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    
    -- Store color info on frame
    frame.currentColor = color
    frame.currentColorType = colorType
    
    -- Also store as unitClass for compatibility with existing code
    if colorType and (colorType == "party_raid" or colorType == "guild" or 
                      colorType == "recently_seen" or colorType == "direct" or
                      colorType == "target" or colorType == "mouseover") then
        frame.unitClass = color
        frame.unitClassFromCache = true
    end
    
    return true
end

-- Update nameplate appearance (main entry point)
function ColorManager:UpdateNameplateAppearance(frame)
    if not frame then return end
    
    -- Get player name and unit from nameplate
    local nameText = select(7, frame:GetRegions())
    local playerName = nameText and nameText:GetText()
    local unit = frame.unit -- Some frames may have unit stored
    
    -- Check if nameplate should be shown based on filters
    if not self:ShouldShowNameplate(frame, playerName) then
        frame:Hide()
        return
    end
    
    -- Try to find unit if not already set
    if not unit and playerName then
        unit = self:FindUnitForNameplate(frame, playerName)
        -- Store the found unit on the frame for future reference
        if unit then
            frame.unit = unit
        end
    end
    
    -- Get and apply color
    local color, colorType = self:GetNameplateColor(frame, playerName, unit)
    if color then
        self:ApplyNameplateColor(frame, color, colorType)
    end
    
    -- Update threat icon if enabled
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
    frame.unit = nil
end

-- Simplified class check (for compatibility)
function ColorManager:ClassCheck(frame)
    if not frame then return false end
    
    -- Get nameplate info
    local nameText = select(7, frame:GetRegions())
    if not nameText then return false end
    
    local playerName = nameText:GetText()
    if not playerName then return false end
    
    -- Check if we already processed this name and have a class
    if frame.lastCheckedName == playerName and frame.unitClass then
        return true
    end
    
    -- Only do class checking if we're in class color mode
    if NotPlater.db.profile.healthBar.coloring.system ~= "class" or
       not NotPlater.db.profile.healthBar.coloring.classColors.enable then
        return false
    end
    
    -- Try to get class color
    local color, colorType = self:GetClassColorFromAllSources(frame, playerName, frame.unit)
    
    if color and (colorType == "party_raid" or colorType == "guild" or 
                  colorType == "recently_seen" or colorType == "direct" or
                  colorType == "target" or colorType == "mouseover") then
        -- Apply the class color
        if frame.healthBar then
            frame.healthBar:SetStatusBarColor(color.r, color.g, color.b, 1)
        end
        
        -- Store class info
        frame.unitClass = color
        frame.unitClassFromCache = true
        frame.lastCheckedName = playerName
        
        return true
    end
    
    return false
end