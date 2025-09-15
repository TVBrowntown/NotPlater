-- modules/guildCache.lua
-- Guild cache using direct frame event handling instead of Ace3

-- Don't do anything if NotPlater doesn't exist
if not NotPlater then return end

-- Create a delayed initialization system
local initAttempts = 0
local maxInitAttempts = 10

local function SafeInitialize()
    initAttempts = initAttempts + 1
    
    -- Check if NotPlater is ready
    if not NotPlater.frame or not NotPlater.db then
        -- If we've tried too many times, give up
        if initAttempts >= maxInitAttempts then
            return
        end
        
        -- Try again in 2 seconds
        local retryFrame = CreateFrame("Frame")
        local elapsed = 0
        retryFrame:SetScript("OnUpdate", function(self, elap)
            elapsed = elapsed + elap
            if elapsed >= 2 then
                retryFrame:SetScript("OnUpdate", nil)
                SafeInitialize()
            end
        end)
        return
    end

    -- NotPlater is ready, set up guild cache
    local GuildCache = {}
    NotPlater.GuildCache = GuildCache

    -- Cache storage
    local guildRoster = {}
    local isInGuild = false
    local lastGuildUpdate = 0
    local initialized = false
    local GUILD_UPDATE_THROTTLE = 2

    -- Create our own frame for event handling
    local guildCacheFrame = CreateFrame("Frame", "NotPlaterGuildCacheFrame")

    -- WoW API functions
    local GetNumGuildMembers = GetNumGuildMembers
    local GetGuildRosterInfo = GetGuildRosterInfo
    local IsInGuild = IsInGuild
    local GuildRoster = GuildRoster
    local GetTime = GetTime
    local RAID_CLASS_COLORS = RAID_CLASS_COLORS
    local strsplit = strsplit

    -- Clear the guild cache (moved up to fix function order)
    function GuildCache:ClearCache()
        for k in pairs(guildRoster) do
            guildRoster[k] = nil
        end
        isInGuild = false
        lastUpdateTime = nil
    end

    -- Update guild membership status
    function GuildCache:UpdateGuildStatus()
        local wasInGuild = isInGuild
        isInGuild = IsInGuild()
        
        if isInGuild and not wasInGuild then
            self:RequestGuildRoster()
        elseif not isInGuild and wasInGuild then
            self:ClearCache()
        end
    end

    -- Request guild roster update with throttling
    function GuildCache:RequestGuildRoster()
        if not isInGuild then return end
        
        local currentTime = GetTime()
        if currentTime - lastGuildUpdate >= GUILD_UPDATE_THROTTLE then
            GuildRoster()
            lastGuildUpdate = currentTime
        end
    end

    -- Update the guild roster cache
    function GuildCache:UpdateRoster()
        if not isInGuild then return end
        
        local numMembers = GetNumGuildMembers()
        if not numMembers or numMembers == 0 then return end
        
        -- Clear existing cache
        for k in pairs(guildRoster) do
            guildRoster[k] = nil
        end
        
        -- Populate cache with current roster
        local membersAdded = 0
        for i = 1, numMembers do
            local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
            
            if name and class and classFileName and RAID_CLASS_COLORS[classFileName] then
                guildRoster[name] = {
                    class = class,
                    classFileName = classFileName,
                    level = level,
                    rank = rank,
                    rankIndex = rankIndex,
                    online = online,
                    classColor = RAID_CLASS_COLORS[classFileName]
                }
                membersAdded = membersAdded + 1
            end
        end
        
        -- Safe print
        if NotPlater.Print and NotPlater.db.profile.guildCache.general.showCacheMessages == true then
            NotPlater:Print(string.format("Guild roster updated: %d members cached", membersAdded))
        end
    end

    -- Get guild member data by name
    function GuildCache:GetMemberData(playerName)
        if not isInGuild or not playerName then return nil end
        
        -- Handle server names
        local name = playerName
        if string.find(playerName, "-") then
            name = strsplit("-", playerName)
        end
        
        return guildRoster[name]
    end

    -- Apply guild member class colors to nameplate
    function GuildCache:ApplyGuildClassColors(frame, playerName)
        -- Safety checks
        if not frame or not frame.healthBar or not playerName then
            return false
        end
        
        -- Check if class colors are enabled
        if not NotPlater.db or not NotPlater.db.profile or 
           not NotPlater.db.profile.threat or
           not NotPlater.db.profile.threat.nameplateColors or
           not NotPlater.db.profile.threat.nameplateColors.general or
           not NotPlater.db.profile.threat.nameplateColors.general.useClassColors or 
           not isInGuild then
            return false
        end
        
        local memberData = self:GetMemberData(playerName)
        if not memberData or not memberData.classColor then
            return false
        end
        
        -- Apply class color to health bar
        frame.healthBar:SetStatusBarColor(
            memberData.classColor.r, 
            memberData.classColor.g, 
            memberData.classColor.b, 
            1
        )
        
        -- Store the class info on the frame for other systems
        frame.unitClass = memberData.classColor
        frame.guildMember = memberData
        
        return true
    end

    -- Enhanced nameplate class checking that includes guild cache
    function GuildCache:EnhancedClassCheck(frame)
        if not frame then return end
        
        -- Get nameplate info
        local nameText = select(7, frame:GetRegions())
        if not nameText then return end
        
        local playerName = nameText:GetText()
        if not playerName then return end
        
        -- First try the guild cache
        if self:ApplyGuildClassColors(frame, playerName) then
            return
        end
        
        -- Fall back to original class check method
        if NotPlater.ClassCheck then
            NotPlater:ClassCheck(frame)
        end
    end

    -- Event handler function
    local function OnEvent(self, event, ...)
        if not initialized then return end
        
        if event == "GUILD_ROSTER_UPDATE" then
            GuildCache:UpdateRoster()
        elseif event == "PLAYER_GUILD_UPDATE" then
            GuildCache:UpdateGuildStatus()
            if isInGuild then
                GuildCache:RequestGuildRoster()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Use a delay for entering world
            local delayFrame = CreateFrame("Frame")
            local elapsed = 0
            delayFrame:SetScript("OnUpdate", function(self, elap)
                elapsed = elapsed + elap
                if elapsed >= 2 then
                    delayFrame:SetScript("OnUpdate", nil)
                    GuildCache:UpdateGuildStatus()
                    if isInGuild then
                        GuildCache:RequestGuildRoster()
                    end
                end
            end)
        end
    end

    -- Initialize the guild cache system
    function GuildCache:Initialize()
        if initialized then return end
        
        if DEFAULT_CHAT_FRAME and NotPlater.db.profile.guildCache.advanced.debugMode == true then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Guild Cache: Starting initialization...")
        end
        
        initialized = true
        
        -- Set up frame-based event handling (no Ace3)
        guildCacheFrame:SetScript("OnEvent", OnEvent)
        guildCacheFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
        guildCacheFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
        guildCacheFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        if DEFAULT_CHAT_FRAME and NotPlater.db.profile.guildCache.advanced.debugMode == true then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Guild Cache: Events registered")
        end
        
        -- Clear cache initially
        self:ClearCache()
        
        -- Check if we're in a guild and update roster
        self:UpdateGuildStatus()
        
        if DEFAULT_CHAT_FRAME and NotPlater.db.profile.guildCache.advanced.debugMode == true then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Guild Cache: Guild status checked, isInGuild = " .. tostring(isInGuild))
        end
        
        -- If already in a guild, request initial roster
        if isInGuild then
            if DEFAULT_CHAT_FRAME and NotPlater.db.profile.guildCache.advanced.debugMode == true then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Guild Cache: Requesting initial guild roster...")
            end
            self:RequestGuildRoster()
        end
        
        if DEFAULT_CHAT_FRAME and NotPlater.db.profile.guildCache.advanced.debugMode == true then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Guild Cache: Initialization complete")
        end
    end

    -- Create initialization function for NotPlater to call
    function NotPlater:InitializeGuildCache()
        if self.GuildCache then
            self.GuildCache:Initialize()
        end
    end

    -- Initialize immediately since we've verified NotPlater is ready
    GuildCache:Initialize()
end

-- Start the safe initialization
SafeInitialize()