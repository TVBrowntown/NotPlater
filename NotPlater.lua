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

-- Initialize addon with proper order and error handling
function NotPlater:OnInitialize()
    -- Create the main frame first
    self.frame = CreateFrame("Frame")
    
    -- Load configuration with error handling
    local success, err = pcall(function()
        self:LoadDefaultConfig()
        self.db = LibStub:GetLibrary("AceDB-3.0"):New("NotPlaterDB", self.defaults)
    end)
    
    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Error loading config: " .. tostring(err))
        -- Create minimal config as fallback
        self:CreateMinimalConfig()
    else
        -- Migrate old config structure if needed
        self:MigrateConfig()
        -- Validate and fix config structure
        self:ValidateConfig()
    end
    
    -- Initialize core systems in proper order
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
    
    -- Initialize enhanced systems with additional delay
    C_Timer.After(0.5, function()
        self:InitializeEnhancedSystems()
    end)
    
    -- Final setup and config validation
    C_Timer.After(1, function()
        -- Force config interface refresh if it exists
        if self.db and self.db.profile then
            -- Trigger a save to ensure all defaults are written
            local currentProfile = self.db:GetCurrentProfile()
            self.db:SetProfile(currentProfile)
        end
        
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Initialization complete")
        end
    end)
end

-- Create minimal fallback config
function NotPlater:CreateMinimalConfig()
    self.db = {
        profile = {
            healthBar = {
                coloring = {
                    system = "reaction",
                    reactionColors = {
                        hostile = {r = 1, g = 0, b = 0, a = 1},
                        neutral = {r = 1, g = 1, b = 0, a = 1},
                        friendly = {r = 0, g = 1, b = 0, a = 1}
                    },
                    classColors = {
                        enable = true,
                        playersOnly = true
                    }
                },
                unitFilters = {
                    showPlayerTotems = true,
                    showOwnTotems = true,
                    showOwnPet = true,
                    showOtherPlayerPets = true
                }
            },
            threatIcon = {
                general = {enable = true, opacity = 1, visibility = "combat"},
                size = {width = 36, height = 36},
                position = {anchor = "RIGHT", xOffset = -32, yOffset = 0}
            },
            threat = {general = {mode = "hdps"}}
        },
        global = {}
    }
end

-- Validate config structure and fix missing values
function NotPlater:ValidateConfig()
    if not self.db or not self.db.profile then
        self:CreateMinimalConfig()
        return
    end
    
    local profile = self.db.profile
    
    -- Ensure healthBar structure
    if not profile.healthBar then
        profile.healthBar = {}
    end
    
    if not profile.healthBar.coloring then
        profile.healthBar.coloring = {}
    end
    
    -- Fix coloring system
    if not profile.healthBar.coloring.system then
        profile.healthBar.coloring.system = "reaction"
    end
    
    -- Fix reaction colors - ensure they're objects with r,g,b,a
    if not profile.healthBar.coloring.reactionColors then
        profile.healthBar.coloring.reactionColors = {}
    end
    
    local reactions = {"hostile", "neutral", "friendly"}
    local defaultColors = {
        hostile = {r = 1, g = 0, b = 0, a = 1},
        neutral = {r = 1, g = 1, b = 0, a = 1},
        friendly = {r = 0, g = 1, b = 0, a = 1}
    }
    
    for _, reaction in ipairs(reactions) do
        local color = profile.healthBar.coloring.reactionColors[reaction]
        if not color or type(color) ~= "table" then
            profile.healthBar.coloring.reactionColors[reaction] = defaultColors[reaction]
        elseif type(color[1]) == "number" then
            -- Convert array format to object format
            profile.healthBar.coloring.reactionColors[reaction] = {
                r = color[1] or defaultColors[reaction].r,
                g = color[2] or defaultColors[reaction].g,
                b = color[3] or defaultColors[reaction].b,
                a = color[4] or defaultColors[reaction].a
            }
        elseif not color.r or not color.g or not color.b then
            -- Fix incomplete color objects
            profile.healthBar.coloring.reactionColors[reaction] = {
                r = color.r or defaultColors[reaction].r,
                g = color.g or defaultColors[reaction].g,
                b = color.b or defaultColors[reaction].b,
                a = color.a or defaultColors[reaction].a
            }
        end
    end
    
    -- Fix class colors settings
    if not profile.healthBar.coloring.classColors then
        profile.healthBar.coloring.classColors = {}
    end
    
    if profile.healthBar.coloring.classColors.enable == nil then
        profile.healthBar.coloring.classColors.enable = true
    end
    
    if profile.healthBar.coloring.classColors.playersOnly == nil then
        profile.healthBar.coloring.classColors.playersOnly = true
    end
    
    -- Fix unit filters
    if not profile.healthBar.unitFilters then
        profile.healthBar.unitFilters = {
            showPlayerTotems = true,
            showOwnTotems = true,
            showOwnPet = true,
            showOtherPlayerPets = true
        }
    end
    
    -- Ensure threat config exists
    if not profile.threat then
        profile.threat = {general = {mode = "hdps"}}
    end
    
    if not profile.threatIcon then
        profile.threatIcon = {
            general = {enable = true, opacity = 1, visibility = "combat"},
            size = {width = 36, height = 36},
            position = {anchor = "RIGHT", xOffset = -32, yOffset = 0}
        }
    end
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

-- Enhanced initialization with proper order
function NotPlater:InitializeEnhancedSystems()
    -- Initialize ColorManager after all other systems are ready
    if self.ColorManager then
        self.ColorManager:Initialize()
        
        -- Force initial color refresh after everything is loaded
        C_Timer.After(2, function()
            if self.FrameManager then
                self.FrameManager:RefreshAllColors()
            end
        end)
    end
end

-- Improved nameplate color update
function NotPlater:UpdateNameplateColors(frame)
    if not frame or not self.ColorManager then return end
    
    -- Mark frame for immediate color update
    frame.needsColorUpdate = true
    
    -- Update immediately if it's target or mouseover
    local nameText = select(7, frame:GetRegions())
    local playerName = nameText and nameText:GetText()
    
    if playerName then
        -- Immediate update for target
        if self:IsTarget(frame) then
            self.ColorManager:UpdateNameplateAppearance(frame)
        end
        
        -- Immediate update for mouseover
        if UnitExists("mouseover") and playerName == UnitName("mouseover") then
            self.ColorManager:UpdateNameplateAppearance(frame)
        end
    end
end

-- Enhanced reload function that ensures proper color updates
function NotPlater:EnhancedReload()
    -- Validate config first
    self:ValidateConfig()
    
    -- Call original reload
    self:Reload()
    
    -- Clear all color caches
    if self.ColorManager then
        -- Clear persistent cache to force fresh color detection
        self.ColorManager:ClearPersistentCache()
        
        -- Update all visible nameplates immediately
        if self.FrameManager then
            self.FrameManager:RefreshAllColors()
        end
    end
    
    -- Force complete refresh with delay
    C_Timer.After(0.1, function()
        if self.FrameManager then
            self.FrameManager:UpdateAllFrames()
        end
    end)
end

-- Override the original Reload function to use enhanced version
local originalReload = NotPlater.Reload
NotPlater.Reload = function(self)
    -- Validate config before reload
    self:ValidateConfig()
    
    if originalReload then
        originalReload(self)
    end
    
    -- Additional enhancements
    C_Timer.After(0.1, function()
        if self.FrameManager then
            self.FrameManager:UpdateAllFrames()
        end
    end)
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
    
    -- Update nameplate colors
    if self.ColorManager then
        self.ColorManager:UpdateNameplateAppearance(frame)
    end
end

-- Configure all frame components
function NotPlater:ConfigureFrame(frame)
    local threatGlow, healthBorder, castBorder, castNoStop, spellIcon, highlightTexture, 
          nameText, levelText, dangerSkull, bossIcon, raidIcon = frame:GetRegions()
    local health = frame:GetChildren()
    
    -- Configure all components
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
    
    -- Apply nameplate colors
    if self.ColorManager then
        self.ColorManager:UpdateNameplateAppearance(frame)
    end
end

-- Reload settings - with config validation
function NotPlater:Reload()
    -- Validate config first
    self:ValidateConfig()
    
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

-- Simplified class check - delegates to ColorManager with fallback
function NotPlater:ClassCheck(frame)
    if not frame then return false end
    
    -- Delegate to ColorManager if available
    if self.ColorManager then
        return self.ColorManager:ClassCheck(frame)
    end
    
    -- Fallback for legacy compatibility (shouldn't be needed with new system)
    return false
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

-- Migrate old config to new structure
function NotPlater:MigrateConfig()
    if not self.db or not self.db.profile then
        return
    end
    
    local profile = self.db.profile
    
    -- Migrate old threat config structure if it exists
    if profile.threat and not profile.threatIcon then
        profile.threatIcon = {
            general = {
                enable = true,
                opacity = 1,
                visibility = "combat"
            },
            size = {
                width = 36,
                height = 36
            },
            position = {
                anchor = "RIGHT",
                xOffset = -32,
                yOffset = 0
            }
        }
    end
    
    -- Ensure basic threat config exists
    if not profile.threat then
        profile.threat = {
            general = {
                mode = "hdps"
            }
        }
    end
    
    -- Migrate old nameplate colors config if it exists
    if profile.threat and profile.threat.nameplateColors and not profile.healthBar.coloring then
        profile.healthBar = profile.healthBar or {}
        profile.healthBar.coloring = {
            system = profile.threat.nameplateColors.general.useClassColors and "class" or "reaction",
            reactionColors = {
                hostile = {r = 1, g = 0, b = 0, a = 1},
                neutral = {r = 1, g = 1, b = 0, a = 1},
                friendly = {r = 0, g = 1, b = 0, a = 1}
            },
            classColors = {
                enable = profile.threat.nameplateColors.general.useClassColors or true,
                playersOnly = true
            }
        }
    end
    
    -- Validate all color values
    self:ValidateConfig()
    
    if self.Print then
        self:Print("Configuration migrated and validated")
    end
end

-- Reset config to defaults (accessible via /np reset)
function NotPlater:ResetConfig()
    if not self.db then
        self:Print("Database not available")
        return
    end
    
    -- Reset to defaults
    self.db:ResetProfile()
    
    -- Apply defaults
    self:LoadDefaultConfig()
    for key, value in pairs(self.defaults.profile) do
        self.db.profile[key] = value
    end
    
    -- Migrate and validate
    self:MigrateConfig()
    self:ValidateConfig()
    
    -- Clear all caches
    if self.ColorManager then
        self.ColorManager:ClearPersistentCache()
    end
    
    -- Reload everything
    if self.EnhancedReload then
        self:EnhancedReload()
    else
        self:Reload()
    end
    
    self:Print("Configuration reset to defaults")
end