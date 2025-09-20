-- modules/core/colorManager.lua
-- Fixed nameplate color management system with better detection

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
local UnitLevel = UnitLevel
local UnitGUID = UnitGUID
local UnitIsUnit = UnitIsUnit
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local GetTime = GetTime
local strsplit = strsplit
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers

-- Persistent color cache
local persistentColorCache = {}
local cacheCleanupTimer = 0

-- Helper function to safely get nameplate info
local function SafeGetNameplateInfo(frame)
    if not frame then return nil, nil, nil end
    
    -- Check if frame has GetRegions method
    if not frame.GetRegions then return nil, nil, nil end
    
    local success, nameText, levelText = pcall(function()
        local regions = {frame:GetRegions()}
        return regions[7], regions[8] -- nameText, levelText
    end)
    
    if not success then return nil, nil, nil end
    
    local playerName, level
    if nameText and nameText.GetText then
        success, playerName = pcall(function() return nameText:GetText() end)
        if not success then playerName = nil end
    end
    
    if levelText and levelText.GetText then
        success, level = pcall(function() return levelText:GetText() end)
        if not success then level = nil end
    end
    
    return playerName, level, levelText
end

-- Initialize the color manager
function ColorManager:Initialize()
    -- Load persistent cache
    self:LoadPersistentCache()
    
    -- Set up cleanup timer
    self:SetupCacheCleanup()
end

-- Load persistent cache from saved variables
function ColorManager:LoadPersistentCache()
    if NotPlater.db and NotPlater.db.global and NotPlater.db.global.persistentColors then
        persistentColorCache = NotPlater.db.global.persistentColors.data or {}
    end
end

-- Save persistent cache to saved variables
function ColorManager:SavePersistentCache()
    if NotPlater.db and NotPlater.db.global then
        if not NotPlater.db.global.persistentColors then
            NotPlater.db.global.persistentColors = {}
        end
        NotPlater.db.global.persistentColors.data = persistentColorCache
        NotPlater.db.global.persistentColors.lastUpdate = GetTime()
    end
end

-- Set up cache cleanup timer
function ColorManager:SetupCacheCleanup()
    local cleanupFrame = CreateFrame("Frame")
    cleanupFrame.elapsed = 0
    cleanupFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 30 then -- Clean every 30 seconds
            self.elapsed = 0
            ColorManager:CleanupOldCacheEntries()
        end
        
        -- Save cache every 60 seconds
        cacheCleanupTimer = cacheCleanupTimer + elapsed
        if cacheCleanupTimer >= 60 then
            cacheCleanupTimer = 0
            ColorManager:SavePersistentCache()
        end
    end)
end

-- Clean up old cache entries
function ColorManager:CleanupOldCacheEntries()
    local currentTime = GetTime()
    local maxAge = 7 * 24 * 60 * 60 -- 7 days in seconds
    
    for name, data in pairs(persistentColorCache) do
        if data.lastSeen and (currentTime - data.lastSeen) > maxAge then
            persistentColorCache[name] = nil
        end
    end
end

-- Store color in persistent cache
function ColorManager:StoreColorInCache(playerName, color, source, className, classFileName, level)
    if not playerName or not color then return end
    
    -- Handle server names
    local name = playerName
    if string.find(playerName, "-") then
        name = strsplit("-", playerName)
    end
    
    -- Store in persistent cache
    persistentColorCache[name] = {
        color = {
            r = color.r,
            g = color.g,
            b = color.b
        },
        source = source,
        className = className,
        classFileName = classFileName,
        level = level,
        lastSeen = GetTime()
    }
end

-- Get color from persistent cache
function ColorManager:GetColorFromCache(playerName)
    if not playerName then return nil end
    
    -- Try exact match first
    local data = persistentColorCache[playerName]
    if data and data.color then
        -- Update last seen time
        data.lastSeen = GetTime()
        return {
            r = data.color.r,
            g = data.color.g,
            b = data.color.b
        }, data.source or "cache"
    end
    
    -- Handle server names
    if string.find(playerName, "-") then
        local name = strsplit("-", playerName)
        data = persistentColorCache[name]
        if data and data.color then
            data.lastSeen = GetTime()
            return {
                r = data.color.r,
                g = data.color.g,
                b = data.color.b
            }, data.source or "cache"
        end
    end
    
    return nil, nil
end

-- Comprehensive unit detection - IMPROVED
function ColorManager:FindAllUnitsForName(playerName, level)
    if not playerName then return {} end
    
    local units = {}
    local unitsToCheck = {"target", "mouseover", "pet", "focus", "targettarget", "mouseovertarget"}
    
    -- Add party members and their targets/pets
    if UnitInParty("player") then
        for i = 1, GetNumPartyMembers() do
            table.insert(unitsToCheck, "party" .. i)
            table.insert(unitsToCheck, "partypet" .. i)
            table.insert(unitsToCheck, "party" .. i .. "target")
        end
        table.insert(unitsToCheck, "player")
    end
    
    -- Add raid members and their targets/pets
    if UnitInRaid("player") then
        for i = 1, GetNumRaidMembers() do
            table.insert(unitsToCheck, "raid" .. i)
            table.insert(unitsToCheck, "raidpet" .. i)
            table.insert(unitsToCheck, "raid" .. i .. "target")
        end
        table.insert(unitsToCheck, "player")
    end
    
    -- Check all units
    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) and UnitName(unit) == playerName then
            -- Additional level check if provided
            if not level or level == tostring(UnitLevel(unit)) then
                table.insert(units, unit)
            end
        end
    end
    
    return units
end

-- Check if unit should have nameplate shown based on filters
function ColorManager:ShouldShowNameplate(frame, playerName)
    -- Safety check
    if not NotPlater.db or not NotPlater.db.profile or not NotPlater.db.profile.healthBar then
        return true
    end
    
    local filters = NotPlater.db.profile.healthBar.unitFilters
    if not filters then
        return true -- Default to showing if no filters configured
    end
    
    -- Find any unit for this nameplate
    local units = self:FindAllUnitsForName(playerName)
    if #units == 0 then
        return true -- Can't determine, show by default
    end
    
    local unit = units[1] -- Use first found unit
    
    -- Check if it's a totem
    if self:IsTotem(unit) then
        if self:IsOwnUnit(unit) then
            return filters.showOwnTotems
        else
            return filters.showPlayerTotems
        end
    end
    
    -- Check if it's a pet/minion
    if self:IsPetOrMinion(unit) then
        if self:IsOwnUnit(unit) or UnitIsUnit(unit, "pet") then
            return filters.showOwnPet
        else
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
        return true
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
    
    return false
end

-- Get class color with comprehensive detection and caching - IMPROVED
function ColorManager:GetClassColorFromAllSources(frame, playerName, unit)
    -- Safety check for valid config
    if not NotPlater.db or not NotPlater.db.profile or not NotPlater.db.profile.healthBar or 
       not NotPlater.db.profile.healthBar.coloring or not NotPlater.db.profile.healthBar.coloring.classColors or
       not NotPlater.db.profile.healthBar.coloring.classColors.enable then
        return self:GetReactionColor(frame, unit)
    end
    
    local playersOnly = NotPlater.db.profile.healthBar.coloring.classColors.playersOnly
    
    -- 1. Check persistent cache first
    local cachedColor, cacheSource = self:GetColorFromCache(playerName)
    if cachedColor then
        return cachedColor, cacheSource
    end
    
    -- 2. Try Party/Raid Cache
    if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.GetMemberData then
        local memberData = NotPlater.PartyRaidCache:GetMemberData(playerName)
        if memberData and memberData.classColor then
            if not playersOnly or memberData.isPlayer ~= false then
                local color = {
                    r = memberData.classColor.r,
                    g = memberData.classColor.g,
                    b = memberData.classColor.b
                }
                self:StoreColorInCache(playerName, color, "party_raid", memberData.class, memberData.classFileName, memberData.level)
                return color, "party_raid"
            end
        end
    end
    
    -- 3. Try Guild Cache
    if NotPlater.GuildCache and NotPlater.GuildCache.GetMemberData then
        local memberData = NotPlater.GuildCache:GetMemberData(playerName)
        if memberData and memberData.classColor then
            if not playersOnly or memberData.isPlayer ~= false then
                local color = {
                    r = memberData.classColor.r,
                    g = memberData.classColor.g,
                    b = memberData.classColor.b
                }
                self:StoreColorInCache(playerName, color, "guild", memberData.class, memberData.classFileName, memberData.level)
                return color, "guild"
            end
        end
    end
    
    -- 4. Try Recently Seen Cache
    if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.GetPlayerData then
        local data = NotPlater.RecentlySeenCache:GetPlayerData(playerName)
        if data and data.classColor then
            if not playersOnly or data.isPlayer ~= false then
                local color = {
                    r = data.classColor.r,
                    g = data.classColor.g,
                    b = data.classColor.b
                }
                self:StoreColorInCache(playerName, color, "recently_seen", data.class, data.classFileName, data.level)
                return color, "recently_seen"
            end
        end
    end
    
    -- 5. Direct unit detection from all possible units - MORE AGGRESSIVE
    local _, level, levelText = SafeGetNameplateInfo(frame)
    local units = self:FindAllUnitsForName(playerName, level)
    
    for _, detectedUnit in ipairs(units) do
        if UnitExists(detectedUnit) then
            if not playersOnly or UnitIsPlayer(detectedUnit) then
                local className, classFileName = UnitClass(detectedUnit)
                if classFileName and RAID_CLASS_COLORS[classFileName] then
                    local color = {
                        r = RAID_CLASS_COLORS[classFileName].r,
                        g = RAID_CLASS_COLORS[classFileName].g,
                        b = RAID_CLASS_COLORS[classFileName].b
                    }
                    
                    -- Store in cache for future use
                    self:StoreColorInCache(playerName, color, "direct", className, classFileName, UnitLevel(detectedUnit))
                    
                    -- Add to recently seen cache if it's a player
                    if UnitIsPlayer(detectedUnit) and NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.AddPlayer then
                        NotPlater.RecentlySeenCache:AddPlayer(playerName, className, classFileName, UnitLevel(detectedUnit))
                    end
                    
                    return color, "direct"
                end
            end
        end
    end
    
    -- Fallback to reaction colors
    return self:GetReactionColor(frame, unit)
end

-- Get reaction-based color - IMPROVED with level text detection
function ColorManager:GetReactionColor(frame, unit)
    -- Safety check for valid config
    if not NotPlater.db or not NotPlater.db.profile or not NotPlater.db.profile.healthBar or 
       not NotPlater.db.profile.healthBar.coloring or not NotPlater.db.profile.healthBar.coloring.reactionColors then
        -- Ultimate fallback colors
        return {r = 1, g = 1, b = 0}, "fallback"
    end
    
    local reactionColors = NotPlater.db.profile.healthBar.coloring.reactionColors
    
    -- Get player name and level text for unit resolution
    local playerName, level, levelText = SafeGetNameplateInfo(frame)
    
    -- If we have a unit, use it directly
    if unit and UnitExists(unit) then
        -- Special handling for player's own units (pets, totems)
        if self:IsOwnUnit(unit) or UnitIsUnit(unit, "pet") then
            return reactionColors.friendly, "own_unit"
        end
        
        local reaction = UnitReaction(unit, "player")
        
        if reaction then
            if reaction <= 2 then
                return reactionColors.hostile, "hostile"
            elseif reaction == 4 then
                return reactionColors.neutral, "neutral"
            elseif reaction >= 5 then
                return reactionColors.friendly, "friendly"
            end
        end
        
        -- Fallback to UnitSelectionColor if reaction detection fails
        local r, g, b = UnitSelectionColor(unit)
        if r and g and b then
            -- Map selection color to reaction
            if r > 0.9 and g < 0.2 and b < 0.2 then
                return reactionColors.hostile, "selection_hostile"
            elseif r > 0.9 and g > 0.6 and b < 0.2 then
                return reactionColors.neutral, "selection_neutral"
            else
                return reactionColors.friendly, "selection_friendly"
            end
        end
    end
    
    -- Try to find units if not provided
    if not unit and playerName then
        local units = self:FindAllUnitsForName(playerName, level)
        if #units > 0 then
            -- Recursively call with found unit
            return self:GetReactionColor(frame, units[1])
        end
    end
    
    -- IMPROVED: Use level text color as reaction indicator
    if levelText then
        local r, g, b = levelText:GetTextColor()
        
        if r and g and b then
            -- Level text color indicates faction:
            -- Red (r > 0.9, g < 0.2, b < 0.2) = Hostile (higher level hostile)
            -- Orange/Red = Hostile
            -- Yellow (r > 0.9, g > 0.9, b < 0.2) = Neutral
            -- Green = Friendly (can quest)
            -- Gray = Trivial (too low level)
            -- White/Normal = Same faction
            
            if r > 0.9 and g < 0.2 and b < 0.2 then
                -- Red level = hostile
                return reactionColors.hostile, "level_hostile"
            elseif r > 0.9 and g > 0.6 and b < 0.2 then
                -- Yellow/Orange level = neutral or hostile
                if r > g then
                    -- More red than green = hostile
                    return reactionColors.hostile, "level_hostile2"
                else
                    -- Yellow = neutral
                    return reactionColors.neutral, "level_neutral"
                end
            elseif g > 0.7 and r < 0.3 and b < 0.3 then
                -- Green level = friendly
                return reactionColors.friendly, "level_friendly"
            elseif r > 0.4 and g > 0.4 and b > 0.4 and r < 0.7 then
                -- Gray level = trivial, check if hostile or friendly based on other factors
                -- Default to neutral for gray
                return reactionColors.neutral, "level_trivial"
            else
                -- White/other = same faction (friendly)
                return reactionColors.friendly, "level_same"
            end
        end
    end
    
    -- Check if we previously detected a reaction
    if frame and frame.detectedReaction then
        local color = reactionColors[frame.detectedReaction]
        if color then
            return color, "cached_" .. frame.detectedReaction
        end
    end
    
    -- Ultimate fallback - neutral is safer than hostile
    return reactionColors.neutral, "fallback"
end

-- Get nameplate color based on system
function ColorManager:GetNameplateColor(frame, playerName, unit)
    if not frame then
        return nil, nil
    end
    
    -- Safety check for valid config
    if not NotPlater.db or not NotPlater.db.profile or not NotPlater.db.profile.healthBar or 
       not NotPlater.db.profile.healthBar.coloring then
        return {r = 1, g = 1, b = 0}, "fallback"
    end
    
    local coloringSystem = NotPlater.db.profile.healthBar.coloring.system
    
    if coloringSystem == "class" then
        return self:GetClassColorFromAllSources(frame, playerName, unit)
    else
        return self:GetReactionColor(frame, unit)
    end
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
    
    -- Also store as unitClass for compatibility
    if colorType and (colorType == "party_raid" or colorType == "guild" or 
                      colorType == "recently_seen" or colorType == "direct" or
                      colorType == "target" or colorType == "mouseover" or
                      colorType == "cache") then
        frame.unitClass = color
        frame.unitClassFromCache = true
    end
    
    return true
end

-- Update nameplate appearance (main entry point) - FIXED
function ColorManager:UpdateNameplateAppearance(frame)
    -- Safety checks
    if not frame then return end
    
    -- Get player name from nameplate safely
    local playerName, level, levelText = SafeGetNameplateInfo(frame)
    if not playerName then return end
    
    -- Check if nameplate should be shown based on filters
    if not self:ShouldShowNameplate(frame, playerName) then
        if frame.Hide then
            frame:Hide()
        end
        return
    end
    
    -- Find a unit for this nameplate
    local unit = nil
    if frame.unit then
        unit = frame.unit
    else
        local units = self:FindAllUnitsForName(playerName, level)
        if #units > 0 then
            unit = units[1]
            frame.unit = unit -- Store for future reference
        end
    end
    
    -- Get and apply color
    local color, colorType = self:GetNameplateColor(frame, playerName, unit)
    if color then
        self:ApplyNameplateColor(frame, color, colorType)
    end
end

-- Clear cached color data from frame
function ColorManager:ClearFrameColorCache(frame)
    if not frame then return end
    
    -- Don't clear everything, just unit-specific data
    frame.unit = nil
    frame.unitClassFromCache = nil
    frame.lastCheckedName = nil
end

-- Simplified class check (for compatibility) - FIXED
function ColorManager:ClassCheck(frame)
    -- Safety checks
    if not frame then return false end
    
    -- Get nameplate info safely
    local playerName, level = SafeGetNameplateInfo(frame)
    if not playerName then return false end
    
    -- Check if we already have a valid class color
    if frame.unitClass and frame.lastCheckedName == playerName then
        return true
    end
    
    -- Only do class checking if we're in class color mode and config is valid
    if not NotPlater.db or not NotPlater.db.profile or not NotPlater.db.profile.healthBar or 
       not NotPlater.db.profile.healthBar.coloring or 
       NotPlater.db.profile.healthBar.coloring.system ~= "class" or
       not NotPlater.db.profile.healthBar.coloring.classColors or
       not NotPlater.db.profile.healthBar.coloring.classColors.enable then
        return false
    end
    
    -- Try to get class color
    local color, colorType = self:GetClassColorFromAllSources(frame, playerName, frame.unit)
    
    if color and (colorType == "party_raid" or colorType == "guild" or 
                  colorType == "recently_seen" or colorType == "direct" or
                  colorType == "target" or colorType == "mouseover" or
                  colorType == "cache") then
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

-- Clear all persistent cache
function ColorManager:ClearPersistentCache()
    persistentColorCache = {}
    self:SavePersistentCache()
end