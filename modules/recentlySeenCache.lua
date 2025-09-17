-- modules/recentlySeenCache.lua
-- Recently Seen Players Cache - Performance Optimized

-- Don't do anything if NotPlater doesn't exist
if not NotPlater then return end

local function SafeInitialize()
    -- Check if NotPlater and AceDB are ready
    if not NotPlater or not NotPlater.db or not NotPlater.db.profile then
        -- Try again in 1 second
        C_Timer.After(1, SafeInitialize)
        return
    end

    -- NotPlater and AceDB are ready, set up recently seen cache
    local RecentlySeenCache = {}
    NotPlater.RecentlySeenCache = RecentlySeenCache

    -- Local references for performance
    local GetTime = GetTime
    local RAID_CLASS_COLORS = RAID_CLASS_COLORS
    local strsplit = strsplit
    local pairs = pairs
    local UnitIsPlayer = UnitIsPlayer
    
    -- Cache storage (will be loaded from SavedVariables)
    local cache = {}
    local initialized = false
    local cacheStats = {
        hits = 0,
        misses = 0,
        added = 0,
        pruned = 0
    }

    -- Create frame for event handling
    local recentlyCacheFrame = CreateFrame("Frame", "NotPlaterRecentlySeenFrame")

    -- Safe print function
    local function SafePrint(message)
        if message and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: " .. tostring(message))
        end
    end

    -- Prune old entries (only called on login/reload)
    function RecentlySeenCache:PruneOldEntries()
        if not NotPlater.db or not NotPlater.db.profile then
            return
        end
        
        local settings = NotPlater.db.profile.recentlySeenCache.general
        if not settings.enable then
            return
        end
        
        local currentTime = GetTime()
        local cutoffTime = currentTime - (settings.pruneDays * 86400) -- Convert days to seconds
        local prunedCount = 0
        
        -- Important: Don't reassign cache, modify it in place
        local toRemove = {}
        for name, data in pairs(cache) do
            if data.lastSeen < cutoffTime then
                table.insert(toRemove, name)
                prunedCount = prunedCount + 1
            end
        end
        
        -- Remove the old entries
        for _, name in ipairs(toRemove) do
            cache[name] = nil
        end
        
        cacheStats.pruned = cacheStats.pruned + prunedCount
        
        -- Limit cache size if needed
        local maxEntries = settings.maxEntries or 500
        local cacheSize = self:GetCacheSize()
        
        if cacheSize > maxEntries then
            self:RemoveOldestEntries(cacheSize - maxEntries)
        end
        
        if settings.showCacheMessages and prunedCount > 0 then
            SafePrint(string.format("Recently Seen Cache: Pruned %d old entries (older than %d days)", 
                prunedCount, settings.pruneDays))
        end
        
        -- Save pruned cache
        self:SaveCache()
    end

    -- Remove oldest entries to stay under max size
    function RecentlySeenCache:RemoveOldestEntries(countToRemove)
        if countToRemove <= 0 then return end
        
        -- Create sorted list by lastSeen time
        local sorted = {}
        for name, data in pairs(cache) do
            table.insert(sorted, {name = name, lastSeen = data.lastSeen})
        end
        
        table.sort(sorted, function(a, b) return a.lastSeen < b.lastSeen end)
        
        -- Remove oldest entries
        for i = 1, math.min(countToRemove, #sorted) do
            cache[sorted[i].name] = nil
            cacheStats.pruned = cacheStats.pruned + 1
        end
    end

    -- Get cache size
    function RecentlySeenCache:GetCacheSize()
        local count = 0
        for _ in pairs(cache) do
            count = count + 1
        end
        return count
    end

    -- Add or update a player in the cache
    function RecentlySeenCache:AddPlayer(playerName, className, classFileName, level)
        if not playerName or not classFileName then return false end
        
        -- Don't cache if disabled
        if not NotPlater.db.profile.recentlySeenCache.general.enable then
            return false
        end
        
        -- Don't cache guild members (they have their own cache)
        if NotPlater.GuildCache and NotPlater.GuildCache.GetMemberData then
            local guildData = NotPlater.GuildCache:GetMemberData(playerName)
            if guildData then
                return false
            end
        end
        
        -- Don't cache party/raid members (they have their own cache)
        if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.GetMemberData then
            local groupData = NotPlater.PartyRaidCache:GetMemberData(playerName)
            if groupData then
                return false
            end
        end
        
        -- Handle server names
        local name = playerName
        if string.find(playerName, "-") then
            name = strsplit("-", playerName)
        end
        
        local classColor = RAID_CLASS_COLORS[classFileName]
        if not classColor then
            return false
        end
        
        -- IMPORTANT: Copy the color values, don't store the reference!
        local colorCopy = {
            r = classColor.r,
            g = classColor.g,
            b = classColor.b
        }
        
        -- Add or update the cache entry
        local isNew = not cache[name]
        cache[name] = {
            class = className,
            classFileName = classFileName,
            level = level or 0,
            lastSeen = GetTime(),
            classColor = colorCopy  -- Use the copy, not the reference
        }
        
        if isNew then
            cacheStats.added = cacheStats.added + 1
            
            -- Check cache size limit
            local settings = NotPlater.db.profile.recentlySeenCache.general
            local maxEntries = settings.maxEntries or 500
            if self:GetCacheSize() > maxEntries then
                self:RemoveOldestEntries(1)
            end
        end
        
        -- Periodically save (every 10 additions)
        if cacheStats.added % 10 == 0 then
            self:SaveCache()
        end
        
        if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
            SafePrint(string.format("Cache Debug: Added/Updated %s (%s) with color r=%.2f g=%.2f b=%.2f", 
                name, className or "Unknown", colorCopy.r, colorCopy.g, colorCopy.b))
        end
        
        return true
    end

    -- Get player data from cache
    function RecentlySeenCache:GetPlayerData(playerName)
        if not playerName then return nil end
        
        -- Try exact match first
        local data = cache[playerName]
        if data then
            cacheStats.hits = cacheStats.hits + 1
            -- Update last seen time when accessed
            data.lastSeen = GetTime()
            return data
        end
        
        -- Handle server names - try without server
        if string.find(playerName, "-") then
            local name = strsplit("-", playerName)
            data = cache[name]
            if data then
                cacheStats.hits = cacheStats.hits + 1
                data.lastSeen = GetTime()
                return data
            end
        end
        
        -- Try case-insensitive match as last resort
        for name, cacheData in pairs(cache) do
            if string.lower(name) == string.lower(playerName) then
                cacheStats.hits = cacheStats.hits + 1
                cacheData.lastSeen = GetTime()
                return cacheData
            end
        end
        
        cacheStats.misses = cacheStats.misses + 1
        return nil
    end

    -- Apply cached class colors to nameplate (main performance function)
    function RecentlySeenCache:ApplyClassColors(frame, playerName)
        -- Safety checks
        if not frame or not playerName then
            return false
        end
        
        -- Clear any existing class data first
        frame.unitClass = nil
        frame.unitClassFromCache = nil
        
        -- Don't apply if disabled or class colors are disabled
        if not NotPlater.db.profile.recentlySeenCache.general.enable or
           not NotPlater.db.profile.recentlySeenCache.general.useRecentlySeenColors or
           not NotPlater.db.profile.threat.nameplateColors.general.useClassColors then
            return false
        end
        
        local data = self:GetPlayerData(playerName)
        if not data or not data.classColor then
            if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
                SafePrint("Cache Debug: No data for " .. playerName)
            end
            return false
        end
        
        -- Make sure healthBar exists
        if not frame.healthBar then
            if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
                SafePrint("Cache Debug: No healthBar on frame for: " .. playerName)
            end
            return false
        end
        
        -- Create a fresh color copy for this frame to avoid reference issues
        local colorCopy = {
            r = data.classColor.r,
            g = data.classColor.g,
            b = data.classColor.b
        }
        
        -- Verify the color values are valid
        if not colorCopy.r or not colorCopy.g or not colorCopy.b then
            SafePrint("Cache Error: Invalid color data for " .. playerName)
            return false
        end
        
        -- Apply the color
        frame.healthBar:SetStatusBarColor(colorCopy.r, colorCopy.g, colorCopy.b, 1)
        
        -- Store a copy on the frame for other systems
        frame.unitClass = colorCopy
        frame.recentlySeen = {
            class = data.class,
            classFileName = data.classFileName,
            level = data.level
        }
        
        -- Mark that we found a class so other checks don't override
        frame.unitClassFromCache = true
        
        if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
            SafePrint(string.format("Cache Debug: Applied %s color (r=%.2f g=%.2f b=%.2f) to %s", 
                data.class or "Unknown", colorCopy.r, colorCopy.g, colorCopy.b, playerName))
        end
        
        return true
    end

    -- Enhanced nameplate check that includes recently seen cache
    function RecentlySeenCache:EnhancedClassCheck(frame)
        if not frame then return false end
        
        -- Clear any old data first
        frame.unitClassFromCache = nil
        
        -- Get the name from the nameplate
        local nameText = select(7, frame:GetRegions())
        if not nameText then return false end
        
        local playerName = nameText:GetText()
        if not playerName then return false end
        
        -- Debug logging
        if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
            SafePrint("Cache Debug: Checking nameplate for: " .. playerName)
        end
        
        -- Simple name-only match for cached players
        local success = self:ApplyClassColors(frame, playerName)
        
        if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
            if success then
                SafePrint("Cache Debug: Found and applied colors for: " .. playerName)
            else
                SafePrint("Cache Debug: No cache entry for: " .. playerName)
            end
        end
        
        return success
    end

    -- Save cache to SavedVariables (AceDB aware)
    function RecentlySeenCache:SaveCache()
        -- AceDB automatically saves, we just need to update the reference
        if not NotPlater.db or not NotPlater.db.global then 
            if NotPlater.db then
                -- Ensure global exists
                NotPlater.db.global = NotPlater.db.global or {}
                NotPlater.db.global.recentlySeenCache = NotPlater.db.global.recentlySeenCache or {}
            else
                return
            end
        end
        
        -- Update the AceDB managed data
        NotPlater.db.global.recentlySeenCache.data = cache
        NotPlater.db.global.recentlySeenCache.stats = cacheStats
        NotPlater.db.global.recentlySeenCache.version = 1
        NotPlater.db.global.recentlySeenCache.lastSave = GetTime()
        
        if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
            local count = self:GetCacheSize()
            SafePrint(string.format("Cache Debug: Saved %d players to AceDB", count))
        end
    end

    -- Load cache from SavedVariables (AceDB aware)
    function RecentlySeenCache:LoadCache()
        -- Wait for AceDB to be ready
        if not NotPlater.db or not NotPlater.db.global or not NotPlater.db.global.recentlySeenCache then
            if NotPlater.db and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
                SafePrint("Cache Debug: AceDB not ready or no saved cache exists")
            end
            -- Initialize empty cache
            cache = {}
            cacheStats = {
                hits = 0,
                misses = 0,
                added = 0,
                pruned = 0
            }
            return
        end
        
        -- Load from AceDB managed data
        local saved = NotPlater.db.global.recentlySeenCache
        if saved and saved.data and next(saved.data) then  -- next() checks if table has any entries
            cache = saved.data
            cacheStats = saved.stats or {
                hits = 0,
                misses = 0,
                added = 0,
                pruned = 0
            }
            
            local loadedCount = self:GetCacheSize()
            if NotPlater.db.profile.recentlySeenCache.general.showCacheMessages then
                SafePrint(string.format("Recently Seen Cache: Loaded %d players", loadedCount))
            end
            
            if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
                SafePrint(string.format("Cache Debug: Successfully loaded from AceDB, last save: %.1f seconds ago", 
                    saved.lastSave and (GetTime() - saved.lastSave) or -1))
                -- List first few players for verification
                local count = 0
                for name, data in pairs(cache) do
                    SafePrint(string.format("  - %s: %s", name, data.class or "Unknown"))
                    count = count + 1
                    if count >= 3 then break end
                end
            end
        else
            -- No saved data
            cache = {}
            cacheStats = {
                hits = 0,
                misses = 0,
                added = 0,
                pruned = 0
            }
            
            if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
                SafePrint("Cache Debug: No saved data in AceDB, starting fresh")
            end
        end
    end

    -- Clear entire cache
    function RecentlySeenCache:ClearCache()
        for k in pairs(cache) do
            cache[k] = nil
        end
        cacheStats.hits = 0
        cacheStats.misses = 0
        cacheStats.added = 0
        cacheStats.pruned = 0
        self:SaveCache()
        
        if NotPlater.db.profile.recentlySeenCache.general.showCacheMessages then
            SafePrint("Recently Seen Cache: Cleared all entries")
        end
    end

    -- Get statistics
    function RecentlySeenCache:GetStatistics()
        return {
            size = self:GetCacheSize(),
            hits = cacheStats.hits,
            misses = cacheStats.misses,
            added = cacheStats.added,
            pruned = cacheStats.pruned,
            hitRate = cacheStats.hits > 0 and 
                (cacheStats.hits / (cacheStats.hits + cacheStats.misses) * 100) or 0
        }
    end

    -- Get cache entries for display (sorted by most recent)
    function RecentlySeenCache:GetCacheList()
        local list = {}
        for name, data in pairs(cache) do
            table.insert(list, {
                name = name,
                class = data.class,
                classColor = data.classColor,
                level = data.level,
                lastSeen = data.lastSeen
            })
        end
        
        -- Sort by most recently seen
        table.sort(list, function(a, b) return a.lastSeen > b.lastSeen end)
        
        return list
    end

    -- Event handler
    local function OnEvent(self, event, ...)
        if not initialized then return end
        
        if event == "PLAYER_LOGIN" then
            -- Load saved cache first
            RecentlySeenCache:LoadCache()
            
            -- Then prune old entries after a delay
            local delayFrame = CreateFrame("Frame")
            local elapsed = 0
            delayFrame:SetScript("OnUpdate", function(self, elap)
                elapsed = elapsed + elap
                if elapsed >= 3 then
                    delayFrame:SetScript("OnUpdate", nil)
                    RecentlySeenCache:PruneOldEntries()
                end
            end)
        elseif event == "PLAYER_ENTERING_WORLD" then
            local isInitialLogin = ...
            if isInitialLogin then
                -- Initial login, load cache
                RecentlySeenCache:LoadCache()
            else
                -- Reload/zone change, just save to be safe
                RecentlySeenCache:SaveCache()
            end
        elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
            RecentlySeenCache:SaveCache()
        end
    end

    -- Initialize the cache system
    function RecentlySeenCache:Initialize()
        if initialized then return end
        
        initialized = true
        
        -- Set up event handling
        recentlyCacheFrame:SetScript("OnEvent", OnEvent)
        recentlyCacheFrame:RegisterEvent("PLAYER_LOGIN")
        recentlyCacheFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        recentlyCacheFrame:RegisterEvent("PLAYER_LOGOUT")
        recentlyCacheFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
        
        -- Load cache immediately since AceDB is ready
        self:LoadCache()
        
        if NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
            local count = self:GetCacheSize()
            SafePrint(string.format("Recently Seen Cache: Initialized with %d entries", count))
        end
    end

    -- Initialize immediately since we've verified everything is ready
    RecentlySeenCache:Initialize()
end

-- Use C_Timer for safer delayed initialization
C_Timer.After(0.5, SafeInitialize)