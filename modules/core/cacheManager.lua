-- modules/core/cacheManager.lua
-- Unified cache management system

if not NotPlater then return end

local CacheManager = {}
NotPlater.CacheManager = CacheManager

-- Registered caches
local caches = {}
local cachePriorities = {}

-- Initialize the cache manager
function CacheManager:Initialize()
    -- Register existing caches
    self:RegisterExistingCaches()
end

-- Register a cache provider
function CacheManager:RegisterCache(name, cacheObject, priority)
    if not name or not cacheObject then return end
    
    -- Validate cache interface
    if not self:ValidateCacheInterface(cacheObject) then
        if NotPlater.Print then
            NotPlater:Print("CacheManager: Cache '" .. name .. "' does not implement required interface")
        end
        return false
    end
    
    caches[name] = cacheObject
    
    -- Add to priority list
    table.insert(cachePriorities, {
        name = name,
        priority = priority,
        cache = cacheObject
    })
    
    -- Sort by priority (lower number = higher priority)
    table.sort(cachePriorities, function(a, b)
        return a.priority < b.priority
    end)
    
    return true
end

-- Validate that cache implements required interface
function CacheManager:ValidateCacheInterface(cache)
    local requiredMethods = {
        "GetMemberData",    -- or GetPlayerData for RecentlySeen
        "IsEnabled"
    }
    
    -- Check for either GetMemberData or GetPlayerData
    if not cache.GetMemberData and not cache.GetPlayerData then
        return false
    end
    
    -- Check IsEnabled
    if type(cache.IsEnabled) ~= "function" then
        -- If no IsEnabled method, check if it has enable config
        if not cache.IsEnabled then
            -- Create a default IsEnabled method
            cache.IsEnabled = function(self)
                -- Try to check various enable paths
                if NotPlater.db and NotPlater.db.profile then
                    -- Check guild cache
                    if self == NotPlater.GuildCache then
                        return NotPlater.db.profile.guildCache and 
                               NotPlater.db.profile.guildCache.general and 
                               NotPlater.db.profile.guildCache.general.enable
                    end
                    -- Check party/raid cache
                    if self == NotPlater.PartyRaidCache then
                        return NotPlater.db.profile.partyRaidCache and 
                               NotPlater.db.profile.partyRaidCache.general and 
                               NotPlater.db.profile.partyRaidCache.general.enable
                    end
                    -- Check recently seen cache
                    if self == NotPlater.RecentlySeenCache then
                        return NotPlater.db.profile.recentlySeenCache and 
                               NotPlater.db.profile.recentlySeenCache.general and 
                               NotPlater.db.profile.recentlySeenCache.general.enable
                    end
                end
                return true -- Default to enabled if we can't determine
            end
        end
    end
    
    return true
end

-- Register existing caches
function CacheManager:RegisterExistingCaches()
    -- Register in priority order
    
    -- 1. Party/Raid Cache (highest priority)
    if NotPlater.PartyRaidCache then
        self:RegisterCache("PartyRaid", NotPlater.PartyRaidCache, 1)
    end
    
    -- 2. Guild Cache
    if NotPlater.GuildCache then
        self:RegisterCache("Guild", NotPlater.GuildCache, 2)
    end
    
    -- 3. Recently Seen Cache (lowest priority)
    if NotPlater.RecentlySeenCache then
        self:RegisterCache("RecentlySeen", NotPlater.RecentlySeenCache, 3)
    end
end

-- Get player class color from all caches
function CacheManager:GetPlayerClassColor(playerName)
    if not playerName then return nil, nil end
    
    -- Check each cache in priority order
    for _, cacheInfo in ipairs(cachePriorities) do
        local cache = cacheInfo.cache
        
        -- Check if cache is enabled
        if cache:IsEnabled() then
            -- Get data from cache (handle different method names)
            local data
            if cache.GetMemberData then
                data = cache:GetMemberData(playerName)
            elseif cache.GetPlayerData then
                data = cache:GetPlayerData(playerName)
            end
            
            -- Return class color if found
            if data and data.classColor then
                -- Return a copy to avoid reference issues
                local colorCopy = {
                    r = data.classColor.r,
                    g = data.classColor.g,
                    b = data.classColor.b
                }
                return colorCopy, cacheInfo.name
            end
        end
    end
    
    return nil, nil
end

-- Check all caches for a player
function CacheManager:CheckAllCaches(frame, playerName)
    if not frame or not playerName then return false end
    
    -- Try to get class color from caches
    local color, source = self:GetPlayerClassColor(playerName)
    
    if color then
        -- Apply color to frame
        if frame.healthBar then
            frame.healthBar:SetStatusBarColor(color.r, color.g, color.b, 1)
        end
        
        -- Store on frame
        frame.unitClass = color
        frame.unitClassFromCache = true
        frame.cacheSource = source
        
        return true
    end
    
    return false
end

-- Clear all cache data
function CacheManager:ClearAllCaches()
    for name, cache in pairs(caches) do
        if cache.ClearCache then
            cache:ClearCache()
        end
    end
end

-- Get cache statistics
function CacheManager:GetStatistics()
    local stats = {}
    
    for name, cache in pairs(caches) do
        local cacheStats = {}
        
        -- Get member/player count
        if cache.GetMemberCount then
            cacheStats.count = cache:GetMemberCount()
        elseif cache.GetCacheSize then
            cacheStats.count = cache:GetCacheSize()
        else
            cacheStats.count = 0
        end
        
        -- Get additional statistics if available
        if cache.GetStatistics then
            local additionalStats = cache:GetStatistics()
            for k, v in pairs(additionalStats) do
                cacheStats[k] = v
            end
        end
        
        stats[name] = cacheStats
    end
    
    return stats
end

-- Force update all caches
function CacheManager:UpdateAllCaches()
    for name, cache in pairs(caches) do
        if cache.UpdateRoster then
            cache:UpdateRoster()
        elseif cache.RequestGuildRoster then
            cache:RequestGuildRoster()
        end
    end
end