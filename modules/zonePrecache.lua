-- modules/zonePrecache.lua
-- Zone-based player pre-caching using /who command for WotLK 3.3.5

if not NotPlater then return end

local function SafeInitialize()
    -- Check if NotPlater is ready
    if not NotPlater or not NotPlater.db or not NotPlater.db.profile then
        C_Timer.After(1, SafeInitialize)
        return
    end

    local ZonePrecache = {}
    NotPlater.ZonePrecache = ZonePrecache

    -- Local references for performance
    local SendWho = SendWho
    local GetNumWhoResults = GetNumWhoResults
    local GetWhoInfo = GetWhoInfo
    local GetRealZoneText = GetRealZoneText
    local GetTime = GetTime
    local UnitLevel = UnitLevel

    -- Cache and state variables
    local initialized = false
    local lastWhoTime = 0
    local currentZone = nil
    local whoInProgress = false
    local whoResults = {}
    local pendingZoneCache = nil
    local suppressWhoUI = false -- Flag to suppress UI during automated queries

    -- Configuration constants
    local WHO_COOLDOWN = 10 -- seconds between /who commands
    local MAX_WHO_RETRIES = 3
    local RETRY_DELAY = 5

    -- Create frame for event handling
    local zonePrecacheFrame = CreateFrame("Frame", "NotPlaterZonePrecacheFrame")

    -- UI Suppression variables - simplified approach
    local uiSuppressionTimer = nil
    
    -- Simple but effective UI suppression for WotLK 3.3.5
    local function StartUISuppressionTimer()
        if uiSuppressionTimer then
            uiSuppressionTimer:Cancel()
        end
        
        -- Aggressively hide the friends frame while suppressing
        uiSuppressionTimer = C_Timer.NewTicker(0.05, function() -- Check every 50ms
            if suppressWhoUI and FriendsFrame and FriendsFrame:IsShown() then
                FriendsFrame:Hide()
                if NotPlater.db.profile.zonePrecache.advanced.debugMode then
                    SafePrint("Zone Debug: Hiding Friends frame")
                end
            elseif not suppressWhoUI then
                -- Stop the timer when no longer suppressing
                if uiSuppressionTimer then
                    uiSuppressionTimer:Cancel()
                    uiSuppressionTimer = nil
                end
            end
        end)
    end
    
    -- Function to stop UI suppression
    local function StopUISuppressionTimer()
        if uiSuppressionTimer then
            uiSuppressionTimer:Cancel()
            uiSuppressionTimer = nil
        end
    end

    -- Safe print function
    local function SafePrint(message)
        if message and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: " .. tostring(message))
        end
    end

    -- Check if zone pre-caching is enabled
    local function IsEnabled()
        return NotPlater.db and 
               NotPlater.db.profile and 
               NotPlater.db.profile.zonePrecache and 
               NotPlater.db.profile.zonePrecache.general and 
               NotPlater.db.profile.zonePrecache.general.enable
    end

    -- Check if recently seen cache is enabled (required for zone pre-caching)
    local function IsRecentlySeenEnabled()
        return NotPlater.db and 
               NotPlater.db.profile and 
               NotPlater.db.profile.recentlySeenCache and 
               NotPlater.db.profile.recentlySeenCache.general and 
               NotPlater.db.profile.recentlySeenCache.general.enable
    end

    -- Process /who results and add players to cache
    function ZonePrecache:ProcessWhoResults()
        -- Clear UI suppression flag and stop timer
        suppressWhoUI = false
        StopUISuppressionTimer()
        
        if not IsEnabled() or not IsRecentlySeenEnabled() then
            return
        end

        local numResults = GetNumWhoResults()
        if numResults == 0 then
            if NotPlater.db.profile.zonePrecache.general.showMessages then
                SafePrint("Zone Pre-cache: No players found in current zone")
            end
            return
        end

        local addedCount = 0
        local skippedCount = 0

        for i = 1, numResults do
            local name, guild, level, race, class, zone, classFileName = GetWhoInfo(i)
            
            if name and class and classFileName then
                -- Check if we should skip this player
                local shouldSkip = false
                
                -- Skip if it's the player themselves
                if name == UnitName("player") then
                    shouldSkip = true
                end
                
                -- Skip guild members if guild cache is enabled (they have their own cache)
                if not shouldSkip and NotPlater.GuildCache and NotPlater.GuildCache.GetMemberData then
                    local guildData = NotPlater.GuildCache:GetMemberData(name)
                    if guildData then
                        shouldSkip = true
                    end
                end
                
                -- Skip party/raid members if cache is enabled
                if not shouldSkip and NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.GetMemberData then
                    local groupData = NotPlater.PartyRaidCache:GetMemberData(name)
                    if groupData then
                        shouldSkip = true
                    end
                end
                
                if shouldSkip then
                    skippedCount = skippedCount + 1
                else
                    -- Try to add to recently seen cache
                    if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.AddPlayer then
                        local success = NotPlater.RecentlySeenCache:AddPlayer(name, class, classFileName, level)
                        if success then
                            addedCount = addedCount + 1
                        else
                            skippedCount = skippedCount + 1
                        end
                    end
                end
            end
        end

        if NotPlater.db.profile.zonePrecache.general.showMessages then
            SafePrint(string.format("Zone Pre-cache: Added %d players, skipped %d (total found: %d)", 
                addedCount, skippedCount, numResults))
        end

        if NotPlater.db.profile.zonePrecache.advanced.debugMode then
            SafePrint(string.format("Zone Debug: Processed /who results for zone '%s'", currentZone or "Unknown"))
        end
    end

    -- Execute /who command for current zone
    function ZonePrecache:ExecuteWhoCommand()
        if not IsEnabled() or not IsRecentlySeenEnabled() then
            return false
        end

        local currentTime = GetTime()
        
        -- Check cooldown
        if currentTime - lastWhoTime < WHO_COOLDOWN then
            if NotPlater.db.profile.zonePrecache.advanced.debugMode then
                local remaining = WHO_COOLDOWN - (currentTime - lastWhoTime)
                SafePrint(string.format("Zone Debug: /who command on cooldown (%.1fs remaining)", remaining))
            end
            return false
        end

        -- Don't execute if already in progress
        if whoInProgress then
            if NotPlater.db.profile.zonePrecache.advanced.debugMode then
                SafePrint("Zone Debug: /who command already in progress")
            end
            return false
        end

        local zone = GetRealZoneText()
        if not zone or zone == "" then
            if NotPlater.db.profile.zonePrecache.advanced.debugMode then
                SafePrint("Zone Debug: No valid zone name found")
            end
            return false
        end

        -- Execute the /who command
        whoInProgress = true
        -- Only suppress UI if the setting is enabled (default true)
        if NotPlater.db.profile.zonePrecache.general.suppressUI ~= false then
            suppressWhoUI = true
            -- Hide the friends frame immediately if it's open
            if FriendsFrame and FriendsFrame:IsShown() then
                FriendsFrame:Hide()
            end
            -- Start the suppression timer
            StartUISuppressionTimer()
        end
        currentZone = zone
        lastWhoTime = currentTime
        
        if NotPlater.db.profile.zonePrecache.advanced.debugMode then
            SafePrint(string.format("Zone Debug: Executing /who for zone '%s'%s", 
                zone, suppressWhoUI and " (UI suppressed)" or ""))
        end
        
        -- Set up a timeout to clear suppression in case WHO_LIST_UPDATE never fires
        if suppressWhoUI then
            C_Timer.After(15, function()
                if suppressWhoUI then
                    if NotPlater.db.profile.zonePrecache.advanced.debugMode then
                        SafePrint("Zone Debug: Timeout - clearing UI suppression")
                    end
                    suppressWhoUI = false
                    whoInProgress = false
                    StopUISuppressionTimer()
                end
            end)
        end
        
        -- Send the who query for current zone
        SendWho("z-" .. zone)
        
        return true
    end

    -- Handle zone changes
    function ZonePrecache:OnZoneChanged()
        if not IsEnabled() or not IsRecentlySeenEnabled() then
            return
        end

        local newZone = GetRealZoneText()
        if not newZone or newZone == "" then
            return
        end

        -- Check if zone actually changed
        if newZone == currentZone then
            return
        end

        currentZone = newZone
        
        if NotPlater.db.profile.zonePrecache.general.showMessages then
            SafePrint(string.format("Zone changed to '%s' - preparing player pre-cache", newZone))
        end

        -- Schedule /who command with a delay to avoid immediate execution on zone change
        local delayFrame = CreateFrame("Frame")
        local elapsed = 0
        local delay = NotPlater.db.profile.zonePrecache.general.zoneChangeDelay or 3
        
        delayFrame:SetScript("OnUpdate", function(self, elap)
            elapsed = elapsed + elap
            if elapsed >= delay then
                delayFrame:SetScript("OnUpdate", nil)
                ZonePrecache:ExecuteWhoCommand()
            end
        end)
    end

    -- Manual trigger for pre-caching current zone
    function ZonePrecache:TriggerManualCache(showUI)
        if not IsEnabled() then
            SafePrint("Zone Pre-cache is disabled in settings")
            return
        end
        
        if not IsRecentlySeenEnabled() then
            SafePrint("Zone Pre-cache requires Recently Seen Cache to be enabled")
            return
        end

        local zone = GetRealZoneText()
        if not zone or zone == "" then
            SafePrint("Unable to determine current zone")
            return
        end

        SafePrint(string.format("Manually triggering zone pre-cache for '%s'%s", 
            zone, showUI and " (showing UI)" or ""))
        
        -- Override suppressWhoUI for manual triggers if requested
        local oldSuppress = suppressWhoUI
        if showUI then
            suppressWhoUI = false
        end
        
        local success = self:ExecuteWhoCommand()
        
        -- Restore original suppress state if we overrode it
        if showUI and not success then
            suppressWhoUI = oldSuppress
        end
    end

    -- Get statistics
    function ZonePrecache:GetStatistics()
        local currentTime = GetTime()
        local cooldownRemaining = math.max(0, WHO_COOLDOWN - (currentTime - lastWhoTime))
        
        return {
            currentZone = currentZone or "Unknown",
            lastWhoTime = lastWhoTime,
            cooldownRemaining = cooldownRemaining,
            whoInProgress = whoInProgress,
            canExecuteWho = cooldownRemaining <= 0 and not whoInProgress
        }
    end

    -- Event handler
    local function OnEvent(self, event, ...)
        if not initialized then return end
        
        if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
            -- Small delay to ensure zone info is updated
            C_Timer.After(1, function()
                ZonePrecache:OnZoneChanged()
            end)
        elseif event == "WHO_LIST_UPDATE" then
            -- IMMEDIATELY hide the friends frame if we're suppressing UI
            if suppressWhoUI and FriendsFrame and FriendsFrame:IsShown() then
                FriendsFrame:Hide()
                if NotPlater.db.profile.zonePrecache.advanced.debugMode then
                    SafePrint("Zone Debug: WHO_LIST_UPDATE - hiding Friends frame")
                end
            end
            
            if whoInProgress then
                whoInProgress = false
                ZonePrecache:ProcessWhoResults()
            else
                -- Safety check: clear suppress flag if we get unexpected WHO_LIST_UPDATE
                suppressWhoUI = false
                StopUISuppressionTimer()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            local isInitialLogin = ...
            if isInitialLogin then
                -- On initial login, cache current zone after a delay
                C_Timer.After(5, function()
                    ZonePrecache:OnZoneChanged()
                end)
            end
        end
    end

    -- Initialize the zone pre-cache system
    function ZonePrecache:Initialize()
        if initialized then return end
        
        initialized = true
        
        -- Set up event handling
        zonePrecacheFrame:SetScript("OnEvent", OnEvent)
        zonePrecacheFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        zonePrecacheFrame:RegisterEvent("ZONE_CHANGED")
        zonePrecacheFrame:RegisterEvent("WHO_LIST_UPDATE")
        zonePrecacheFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        -- Initialize current zone
        currentZone = GetRealZoneText()
        
        if NotPlater.db.profile.zonePrecache.advanced.debugMode then
            SafePrint(string.format("Zone Pre-cache: Initialized for zone '%s'", currentZone or "Unknown"))
        end
    end

    -- Initialize immediately
    ZonePrecache:Initialize()
end

-- Start initialization
C_Timer.After(0.5, SafeInitialize)