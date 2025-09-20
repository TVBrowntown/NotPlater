-- modules/partyRaidCache.lua
-- Party/Raid cache using direct frame event handling

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

    -- NotPlater is ready, set up party/raid cache
    local PartyRaidCache = {}
    NotPlater.PartyRaidCache = PartyRaidCache

    -- Cache storage
    local partyRaidRoster = {}
    local isInGroup = false
    local groupType = nil -- "party" or "raid"
    local lastUpdateTime = nil
    local initialized = false

    -- Create our own frame for event handling
    local partyRaidCacheFrame = CreateFrame("Frame", "NotPlaterPartyRaidCacheFrame")

    -- Safe print function
    local function SafePrint(message)
        if message and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: " .. tostring(message))
        end
    end

    local GetNumPartyMembers = GetNumPartyMembers
    local GetNumRaidMembers = GetNumRaidMembers
    local GetRaidRosterInfo = GetRaidRosterInfo
    local UnitName = UnitName
    local UnitClass = UnitClass
    local UnitLevel = UnitLevel
    local UnitInParty = UnitInParty
    local UnitInRaid = UnitInRaid
    local GetTime = GetTime
    local RAID_CLASS_COLORS = RAID_CLASS_COLORS
    local strsplit = strsplit

    -- Clear the cache
    function PartyRaidCache:ClearCache()
        for k in pairs(partyRaidRoster) do
            partyRaidRoster[k] = nil
        end
        isInGroup = false
        groupType = nil
        lastUpdateTime = nil
        
        if NotPlater.db and NotPlater.db.profile.partyRaidCache.general.showCacheMessages then
            SafePrint("Party/Raid cache cleared")
        end
    end

    -- Update group status
    function PartyRaidCache:UpdateGroupStatus()
        local wasInGroup = isInGroup
        local oldGroupType = groupType
        
        if UnitInRaid("player") then
            isInGroup = true
            groupType = "raid"
        elseif UnitInParty("player") then
            isInGroup = true
            groupType = "party"
        else
            isInGroup = false
            groupType = nil
        end
        
        -- Handle group changes
        if not wasInGroup and isInGroup then
            -- Just joined a group
            self:UpdateRoster()
            if NotPlater.db and NotPlater.db.profile.partyRaidCache.general.showCacheMessages then
                SafePrint("Joined " .. groupType .. " - caching members")
            end
        elseif wasInGroup and not isInGroup then
            -- Left the group
            self:ClearCache()
        elseif oldGroupType ~= groupType then
            -- Changed from party to raid or vice versa
            self:UpdateRoster()
            if NotPlater.db and NotPlater.db.profile.partyRaidCache.general.showCacheMessages then
                SafePrint("Group type changed to " .. (groupType or "none") .. " - updating cache")
            end
        end
    end

    -- Update the roster cache
    function PartyRaidCache:UpdateRoster()
        if not isInGroup then return end
        
        -- Clear existing cache
        for k in pairs(partyRaidRoster) do
            partyRaidRoster[k] = nil
        end
        
        local membersAdded = 0
        
        if groupType == "raid" then
            -- Cache raid members
            local numMembers = GetNumRaidMembers()
            for i = 1, numMembers do
                local name, rank, subgroup, level, class, classFileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
                if name and class and classFileName and RAID_CLASS_COLORS[classFileName] then
                    partyRaidRoster[name] = {
                        class = class,
                        classFileName = classFileName,
                        level = level,
                        online = online,
                        subgroup = subgroup,
                        role = role,
                        classColor = RAID_CLASS_COLORS[classFileName],
                        unitID = "raid" .. i
                    }
                    membersAdded = membersAdded + 1
                end
            end
        elseif groupType == "party" then
            -- Cache party members (including player)
            -- Add player first
            local playerName = UnitName("player")
            local playerClass, playerClassFile = UnitClass("player")
            local playerLevel = UnitLevel("player")
            
            if playerName and playerClassFile and RAID_CLASS_COLORS[playerClassFile] then
                partyRaidRoster[playerName] = {
                    class = playerClass,
                    classFileName = playerClassFile,
                    level = playerLevel,
                    online = true,
                    classColor = RAID_CLASS_COLORS[playerClassFile],
                    unitID = "player"
                }
                membersAdded = membersAdded + 1
            end
            
            -- Add party members
            for i = 1, GetNumPartyMembers() do
                local unitID = "party" .. i
                local name = UnitName(unitID)
                local class, classFileName = UnitClass(unitID)
                local level = UnitLevel(unitID)
                
                if name and classFileName and RAID_CLASS_COLORS[classFileName] then
                    partyRaidRoster[name] = {
                        class = class,
                        classFileName = classFileName,
                        level = level,
                        online = UnitIsConnected(unitID),
                        classColor = RAID_CLASS_COLORS[classFileName],
                        unitID = unitID
                    }
                    membersAdded = membersAdded + 1
                end
            end
        end
        
        lastUpdateTime = GetTime()
        
        if NotPlater.db and NotPlater.db.profile.partyRaidCache.general.showCacheMessages then
            SafePrint(string.format("%s roster updated: %d members cached", groupType or "Group", membersAdded))
        end
    end

    -- Get member data by name
    function PartyRaidCache:GetMemberData(playerName)
        if not isInGroup or not playerName then return nil end
        
        -- Handle server names
        local name = playerName
        if string.find(playerName, "-") then
            name = strsplit("-", playerName)
        end
        
        return partyRaidRoster[name]
    end

    -- Get member count
    function PartyRaidCache:GetMemberCount()
        local count = 0
        for _ in pairs(partyRaidRoster) do
            count = count + 1
        end
        return count
    end

    -- Get member list for config display
    function PartyRaidCache:GetMemberList()
        local members = {}
        for name, data in pairs(partyRaidRoster) do
            table.insert(members, {
                name = name,
                class = data.class,
                classColor = data.classColor,
                level = data.level,
                online = data.online,
                subgroup = data.subgroup,
                role = data.role,
                unitID = data.unitID
            })
        end
        return members
    end

    -- Get last update time
    function PartyRaidCache:GetLastUpdateTime()
        return lastUpdateTime
    end

    -- Get current group type
    function PartyRaidCache:GetGroupType()
        return groupType
    end

    -- Apply party/raid member class colors to nameplate
    function PartyRaidCache:ApplyGroupClassColors(frame, playerName)
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
           not isInGroup then
            return false
        end
        
        -- Check if party/raid cache is enabled
        if not NotPlater.db.profile.partyRaidCache or
           not NotPlater.db.profile.partyRaidCache.general or
           not NotPlater.db.profile.partyRaidCache.general.enable then
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
        frame.partyRaidMember = memberData
        
        return true
    end

    -- Enhanced nameplate class checking that includes party/raid cache
    function PartyRaidCache:EnhancedClassCheck(frame)
        if not frame then return false end
        
        -- Early exit checks
        if not isInGroup then return false end
        
        -- Check if class colors are enabled
        if not NotPlater.db or not NotPlater.db.profile or 
           not NotPlater.db.profile.threat or
           not NotPlater.db.profile.threat.nameplateColors or
           not NotPlater.db.profile.threat.nameplateColors.general or
           not NotPlater.db.profile.threat.nameplateColors.general.useClassColors then
            return false
        end
        
        -- Check if party/raid cache is enabled
        if not NotPlater.db.profile.partyRaidCache or
           not NotPlater.db.profile.partyRaidCache.general or
           not NotPlater.db.profile.partyRaidCache.general.enable then
            return false
        end
        
        -- Get nameplate info
        local nameText = select(7, frame:GetRegions())
        if not nameText then return false end
        
        local playerName = nameText:GetText()
        if not playerName then return false end
        
        -- Check if we already processed this name
        if frame.lastCheckedName == playerName and frame.unitClass then
            return true
        end
        
        local memberData = self:GetMemberData(playerName)
        if not memberData or not memberData.classColor then
            return false
        end
        
        -- Safety check for healthBar
        if not frame.healthBar then
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
        frame.partyRaidMember = memberData
        frame.lastCheckedName = playerName
        
        return true
    end

    -- Event handler function
    local function OnEvent(self, event, ...)
        if not initialized then return end
        
        if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
            PartyRaidCache:UpdateGroupStatus()
            if isInGroup then
                PartyRaidCache:UpdateRoster()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Use a delay for entering world
            local delayFrame = CreateFrame("Frame")
            local elapsed = 0
            delayFrame:SetScript("OnUpdate", function(self, elap)
                elapsed = elapsed + elap
                if elapsed >= 1 then
                    delayFrame:SetScript("OnUpdate", nil)
                    PartyRaidCache:UpdateGroupStatus()
                    if isInGroup then
                        PartyRaidCache:UpdateRoster()
                    end
                end
            end)
        end
    end

    -- Initialize the party/raid cache system
    function PartyRaidCache:Initialize()
        if initialized then return end
        
        if NotPlater.db and NotPlater.db.profile.partyRaidCache.advanced.debugMode then
            SafePrint("Party/Raid Cache: Starting initialization...")
        end
        
        initialized = true
        
        -- Set up frame-based event handling
        partyRaidCacheFrame:SetScript("OnEvent", OnEvent)
        partyRaidCacheFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        partyRaidCacheFrame:RegisterEvent("RAID_ROSTER_UPDATE")
        partyRaidCacheFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        if NotPlater.db and NotPlater.db.profile.partyRaidCache.advanced.debugMode then
            SafePrint("Party/Raid Cache: Events registered")
        end
        
        -- Clear cache initially
        self:ClearCache()
        
        -- Check if we're in a group and update roster
        self:UpdateGroupStatus()
        
        if NotPlater.db and NotPlater.db.profile.partyRaidCache.advanced.debugMode then
            SafePrint("Party/Raid Cache: Group status checked, isInGroup = " .. tostring(isInGroup) .. ", type = " .. tostring(groupType))
        end
        
        -- If already in a group, get initial roster
        if isInGroup then
            self:UpdateRoster()
        end
        
        if NotPlater.db and NotPlater.db.profile.partyRaidCache.advanced.debugMode then
            SafePrint("Party/Raid Cache: Initialization complete")
        end
    end

    -- Create initialization function for NotPlater to call
    function NotPlater:InitializePartyRaidCache()
        if self.PartyRaidCache then
            self.PartyRaidCache:Initialize()
        end
    end

    -- Initialize immediately since we've verified NotPlater is ready
    PartyRaidCache:Initialize()
end

-- Start the safe initialization
SafeInitialize()