-- NotPlater.lua
-- Simplified core module with delegated responsibilities

NotPlater = LibStub("AceAddon-3.0"):NewAddon("NotPlater", "AceEvent-3.0", "AceHook-3.0")
NotPlater.revision = "v2.0.6"

-- Local references for performance
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitHealth = UnitHealth
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Initialize addon
function NotPlater:OnInitialize()
    -- Create the main frame first
    self.frame = CreateFrame("Frame")
    
    -- Load configuration
    self:LoadDefaultConfig()
    self.db = LibStub:GetLibrary("AceDB-3.0"):New("NotPlaterDB", self.defaults)
    
    -- Initialize core systems
    self:InitializeCoreModules()
    
    -- Set up party/raid tracking
    self:PARTY_MEMBERS_CHANGED()
    self:RAID_ROSTER_UPDATE()
    
    -- Register events
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("RAID_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    -- Initialize frame manager
    if self.FrameManager then
        self.FrameManager:Initialize()
    end
    
    -- Load shared media
    self.SML = LibStub:GetLibrary("LibSharedMedia-3.0")
    
    -- Apply current settings
    self:Reload()
    
    -- Initialize caches with delay
    C_Timer.After(0.1, function()
        self:InitializeCaches()
    end)
end

-- Initialize core modules
function NotPlater:InitializeCoreModules()
    -- Initialize Color Manager
    if self.ColorManager then
        self.ColorManager:Initialize()
    end
    
    -- Initialize Cache Manager
    if self.CacheManager then
        self.CacheManager:Initialize()
    end
    
    -- Initialize Threat Provider
    if self.ThreatProvider then
        self.ThreatProvider:Initialize()
    end
end

-- Initialize cache modules
function NotPlater:InitializeCaches()
    -- Guild Cache
    if self.GuildCache and self.GuildCache.Initialize then
        self.GuildCache:Initialize()
    end
    
    -- Party/Raid Cache
    if self.PartyRaidCache and self.PartyRaidCache.Initialize then
        self.PartyRaidCache:Initialize()
    end
    
    -- Recently Seen Cache
    if self.RecentlySeenCache and self.RecentlySeenCache.Initialize then
        self.RecentlySeenCache:Initialize()
    end
end

-- Check if frame is target
function NotPlater:IsTarget(frame)
    local targetExists = UnitExists('target')
    if not targetExists then
        return false
    end

    local nameText = select(7, frame:GetRegions())
    local targetName = UnitName('target')

    return nameText and targetName == nameText:GetText() and frame:GetAlpha() >= 0.99
end

-- Simplified PrepareFrame - delegates to specialized handlers
function NotPlater:PrepareFrame(frame)
    -- Skip if already prepared
    if frame.npHooked then
        -- Just reconfigure components
        self:ReconfigureFrame(frame)
        return
    end
    
    -- Mark as hooked
    frame.npHooked = true
    
    -- Get frame regions
    local threatGlow, healthBorder, castBorder, castNoStop, spellIcon, highlightTexture, 
          nameText, levelText, dangerSkull, bossIcon, raidIcon = frame:GetRegions()
    local health, cast = frame:GetChildren()
    
    -- Store references
    frame.nameText = nameText
    frame.levelText = levelText
    frame.bossIcon = bossIcon
    frame.raidIcon = raidIcon
    
    -- Hide default elements
    if healthBorder then healthBorder:Hide() end
    if threatGlow then threatGlow:SetTexCoord(0, 0, 0, 0) end
    if castNoStop then castNoStop:SetTexCoord(0, 0, 0, 0) end
    if dangerSkull then dangerSkull:SetTexCoord(0, 0, 0, 0) end
    if highlightTexture then highlightTexture:SetTexCoord(0, 0, 0, 0) end
    
    -- Store default cast elements
    frame.defaultCast = cast
    frame.defaultCastBorder = castBorder
    frame.defaultSpellIcon = spellIcon
    
    -- Create highlight texture
    frame.highlightTexture = frame:CreateTexture(nil, "ARTWORK")
    
    -- Construct components
    self:ConstructHealthBar(frame, health)
    self:ConstructThreatComponents(frame.healthBar)
    self:ConstructThreatIcon(frame)
    self:ConstructCastBar(frame)
    self:ConstructTarget(frame)
    
    -- Hide old health bar
    if health then health:Hide() end
    
    -- Configure components
    self:ConfigureFrame(frame)
end

-- Reconfigure existing frame
function NotPlater:ReconfigureFrame(frame)
    local threatGlow, healthBorder, castBorder, castNoStop, spellIcon, highlightTexture, 
          nameText, levelText, dangerSkull, bossIcon, raidIcon = frame:GetRegions()
    
    self:ConfigureThreatComponents(frame)
    self:ConfigureThreatIcon(frame)
    self:ConfigureHealthBar(frame, frame.healthBar and frame.healthBar:GetParent() or frame:GetChildren())
    self:ConfigureCastBar(frame)
    self:ConfigureStacking(frame)
    
    if bossIcon and raidIcon then
        self:ConfigureGeneralisedIcon(bossIcon, frame.healthBar, self.db.profile.bossIcon)
        self:ConfigureGeneralisedIcon(raidIcon, frame.healthBar, self.db.profile.raidIcon)
    end
    
    if levelText and nameText then
        self:ConfigureLevelText(levelText, frame.healthBar)
        self:ConfigureNameText(nameText, frame.healthBar)
    end
    
    self:ConfigureTarget(frame)
    self:TargetCheck(frame)
end

-- Configure all frame components
function NotPlater:ConfigureFrame(frame)
    local threatGlow, healthBorder, castBorder, castNoStop, spellIcon, highlightTexture, 
          nameText, levelText, dangerSkull, bossIcon, raidIcon = frame:GetRegions()
    local health = frame:GetChildren()
    
    -- Configure all components
    self:ConfigureThreatComponents(frame)
    self:ConfigureThreatIcon(frame)
    self:ConfigureHealthBar(frame, health)
    self:ConfigureCastBar(frame)
    self:ConfigureStacking(frame)
    
    if bossIcon and raidIcon then
        self:ConfigureGeneralisedIcon(bossIcon, frame.healthBar, self.db.profile.bossIcon)
        self:ConfigureGeneralisedIcon(raidIcon, frame.healthBar, self.db.profile.raidIcon)
    end
    
    if levelText and nameText then
        self:ConfigureLevelText(levelText, frame.healthBar)
        self:ConfigureNameText(nameText, frame.healthBar)
    end
    
    self:ConfigureTarget(frame)
    self:TargetCheck(frame)
end

-- Reload settings
function NotPlater:Reload()
    -- Ensure frame exists
    if not self.frame then
        self.frame = CreateFrame("Frame")
    end
    
    -- Update cast bar events
    if self.db.profile.castBar.statusBar.general.enable then
        self:RegisterCastBarEvents(self.frame)
    else
        self:UnregisterCastBarEvents(self.frame)
    end
    
    -- Update mouseover events
    if self.db.profile.threat.general.enableMouseoverUpdate then
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    else
        self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
    end
    
    -- Update all existing frames
    if self.FrameManager then
        self.FrameManager:UpdateAllFrames()
    end
end

-- Target changed event
function NotPlater:PLAYER_TARGET_CHANGED()
    if self.FrameManager then
        local frames = self.FrameManager:GetManagedFrames()
        for frame in pairs(frames) do
            frame.targetChanged = true
        end
    end
end

-- Update mouseover unit threat
function NotPlater:UPDATE_MOUSEOVER_UNIT()
    if not self.db.profile.threat.general.enableMouseoverUpdate then
        return
    end
    
    if UnitCanAttack("player", "mouseover") and not UnitIsDeadOrGhost("mouseover") and 
       UnitAffectingCombat("mouseover") then
        local mouseOverGuid = UnitGUID("mouseover")
        local targetGuid = UnitGUID("target")
        
        if self.FrameManager then
            local frames = self.FrameManager:GetManagedFrames()
            for frame in pairs(frames) do
                if frame:IsShown() then
                    if mouseOverGuid == targetGuid and self:IsTarget(frame) then
                        self:MouseoverThreatCheck(frame.healthBar, targetGuid)
                        frame.highlightTexture:Show()
                    else
                        local nameText, levelText = select(7, frame:GetRegions())
                        local name = nameText and nameText:GetText()
                        local level = levelText and levelText:GetText()
                        
                        if name and level then
                            local _, healthMaxValue = frame.healthBar:GetMinMaxValues()
                            local healthValue = frame.healthBar:GetValue()
                            
                            if name == UnitName("mouseover") and 
                               level == tostring(UnitLevel("mouseover")) and 
                               healthValue == UnitHealth("mouseover") and 
                               healthValue ~= healthMaxValue then
                                self:MouseoverThreatCheck(frame.healthBar, mouseOverGuid)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Simplified class check - mostly delegates to cache system
function NotPlater:ClassCheck(frame)
    if frame.unitClass then return end
    
    local nameText, levelText = select(7, frame:GetRegions())
    if not nameText or not levelText then return end
    
    local name = nameText:GetText()
    if not name then return end
    
    -- Try cache manager first
    if self.CacheManager then
        if self.CacheManager:CheckAllCaches(frame, name) then
            return
        end
    end
    
    -- Fallback to direct detection
    local level = levelText:GetText()
    local healthValue = frame.healthBar and frame.healthBar:GetValue()
    
    if not level or not healthValue then return end
    
    -- Check target
    if self:IsTarget(frame) then
        local className, classFileName = UnitClass("target")
        if classFileName and RAID_CLASS_COLORS[classFileName] then
            frame.unitClass = RAID_CLASS_COLORS[classFileName]
            
            -- Add to recently seen cache
            if self.RecentlySeenCache and self.RecentlySeenCache.AddPlayer then
                self.RecentlySeenCache:AddPlayer(name, className, classFileName, UnitLevel("target"))
            end
            
            -- Apply color
            if frame.healthBar then
                frame.healthBar:SetStatusBarColor(frame.unitClass.r, frame.unitClass.g, frame.unitClass.b, 1)
            end
            return
        end
    end
    
    -- Check mouseover
    if name == UnitName("mouseover") and level == tostring(UnitLevel("mouseover")) and 
       healthValue == UnitHealth("mouseover") then
        local className, classFileName = UnitClass("mouseover")
        if classFileName and RAID_CLASS_COLORS[classFileName] then
            frame.unitClass = RAID_CLASS_COLORS[classFileName]
            
            -- Add to recently seen cache
            if self.RecentlySeenCache and self.RecentlySeenCache.AddPlayer and UnitIsPlayer("mouseover") then
                self.RecentlySeenCache:AddPlayer(name, className, classFileName, UnitLevel("mouseover"))
            end
            
            -- Apply color
            if frame.healthBar then
                frame.healthBar:SetStatusBarColor(frame.unitClass.r, frame.unitClass.g, frame.unitClass.b, 1)
            end
        end
    end
end

-- Mouseover threat check
function NotPlater:MouseoverThreatCheck(healthFrame, guid)
    if not healthFrame then return end
    
    local frame = healthFrame:GetParent()
    if not frame then return end
    
    if not self.db.profile.threat.general.enableMouseoverUpdate then
        return
    end
    
    -- Update colors based on threat
    if self.ColorManager then
        self.ColorManager:UpdateNameplateAppearance(frame)
    end
end

-- Party/Raid roster updates
function NotPlater:RAID_ROSTER_UPDATE()
    self.raid = nil
    if UnitInRaid("player") then
        self.raid = {}
        local raidNum = GetNumRaidMembers()
        local i = 1
        while raidNum > 0 and i <= MAX_RAID_MEMBERS do
            if GetRaidRosterInfo(i) then
                local guid = UnitGUID("raid" .. i)
                self.raid[guid] = "raid" .. i
                
                local pet = UnitGUID("raidpet" .. i)
                if pet then
                    self.raid[pet] = "raidpet" .. i
                end
                raidNum = raidNum - 1
            end
            i = i + 1
        end
    end
end

function NotPlater:PARTY_MEMBERS_CHANGED()
    self.party = nil
    if UnitInParty("party1") then
        local partyNum = GetNumPartyMembers()
        local i = 1
        self.party = {}
        while partyNum > 0 and i < MAX_PARTY_MEMBERS do
            if GetPartyMember(i) then
                self.party[UnitGUID("party" .. i)] = "party" .. i
                local pet = UnitGUID("partypet" .. i)
                if pet then
                    self.party[pet] = "partypet" .. i
                end
                partyNum = partyNum - 1
            end
            i = i + 1
        end
        self.party[UnitGUID("player")] = "player"
        local pet = UnitGUID("pet")
        if pet then
            self.party[pet] = "pet"
        end
    end
end