NotPlater = LibStub("AceAddon-3.0"):NewAddon("NotPlater", "AceEvent-3.0", "AceHook-3.0")
NotPlater.revision = "v2.0.6"

local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitHealth = UnitHealth
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local frames = {}
local numChildren = -1

-- DO NOT create frame here - wait for OnInitialize

function NotPlater:OnInitialize()
	-- Create the frame FIRST in OnInitialize
	self.frame = CreateFrame("Frame")
	
	self:LoadDefaultConfig()

	self.db = LibStub:GetLibrary("AceDB-3.0"):New("NotPlaterDB", self.defaults)

	self:PARTY_MEMBERS_CHANGED()
	self:RAID_ROSTER_UPDATE()
	
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	
	self:Reload()

	self.SML = LibStub:GetLibrary("LibSharedMedia-3.0")
	
	-- Set up frame scripts AFTER frame is created
	self:SetupFrameScripts()

	 -- Initialize caches after AceDB is ready
    C_Timer.After(0.1, function()
        if self.GuildCache and self.GuildCache.Initialize then
            self.GuildCache:Initialize()
        end
        if self.PartyRaidCache and self.PartyRaidCache.Initialize then
            self.PartyRaidCache:Initialize()
        end
        if self.RecentlySeenCache and self.RecentlySeenCache.Initialize then
            self.RecentlySeenCache:Initialize()
        end
    end)
end

function NotPlater:CleanupDeadFrames()
    local deadFrames = {}
    for frame in pairs(frames) do
        if not frame:GetParent() or not frame:IsVisible() then
            table.insert(deadFrames, frame)
        end
    end
    
    for _, frame in ipairs(deadFrames) do
        frames[frame] = nil
        if frame.healthBar then
            frame.healthBar.lastValue = nil
            frame.healthBar.lastMaxValue = nil
        end
        frame.unitClass = nil
        frame.wasTarget = nil
    end
end

function NotPlater:SetupFrameScripts()
	-- Make sure frame exists
	if not self.frame then
		self.frame = CreateFrame("Frame")
	end
	
	-- Set up the OnUpdate script with throttling
	local updateThrottle = 0
	local cleanupTimer = 0  -- Move this outside the OnUpdate function
	local UPDATE_INTERVAL = 0.1 -- Update every 0.1 seconds instead of every frame
	
	self.frame:SetScript("OnUpdate", function(self, elapsed)
		updateThrottle = updateThrottle + elapsed
		if updateThrottle >= UPDATE_INTERVAL then
			if(WorldFrame:GetNumChildren() ~= numChildren) then
				numChildren = WorldFrame:GetNumChildren()
				NotPlater:HookFrames(WorldFrame:GetChildren())
			end
			updateThrottle = 0
		end
		
		-- Add cleanup every 30 seconds
		cleanupTimer = cleanupTimer + elapsed
		if cleanupTimer >= 30 then
		    NotPlater:CleanupDeadFrames()
		    cleanupTimer = 0
		end
	end)

	-- Set up the OnEvent script
	self.frame:SetScript("OnEvent", function(self, event, unit)
	    for frame in pairs(frames) do
	        if frame:IsShown() then
	            if unit == "target" then
	                -- Only show cast bar on the actual target nameplate
	                if NotPlater:IsTarget(frame) then
	                    frame.healthBar.lastUnitMatch = "target"
	                    NotPlater:CastBarOnCast(frame, event, unit)
	                else
	                    -- Hide cast bar on non-target nameplates
	                    if frame.castBar and frame.castBar:IsShown() then
	                        frame.castBar:Hide()
	                        frame.castBar.casting = nil
	                        frame.castBar.channeling = nil
	                    end
	                end
	            else
	                -- For non-target units, use the existing matching logic
	                local nameText, levelText = select(7, frame:GetRegions())
	                local name = nameText:GetText()
	                local level = levelText:GetText()
	                local _, healthMaxValue = frame.healthBar:GetMinMaxValues()
	                local healthValue = frame.healthBar:GetValue()
	                if name == UnitName(unit) and level == tostring(UnitLevel(unit)) and healthValue == UnitHealth(unit) and healthValue ~= healthMaxValue then
	                    frame.healthBar.lastUnitMatch = unit
	                    NotPlater:CastBarOnCast(frame, event, unit)
	                end
	            end
	        end
	    end
	end)
end

function NotPlater:IsTarget(frame)
    local targetExists = UnitExists('target')
    if not targetExists then
        return false
    end

	local nameText  = select(7,frame:GetRegions())
    local targetName = UnitName('target')

	return nameText and targetName == nameText:GetText() and frame:GetAlpha() >= 0.99
end

function NotPlater:ImmediateCacheCheck(frame)
	-- Quick cache check for immediate coloring
	if not self.db.profile.threat.nameplateColors.general.useClassColors then
		return false
	end
	
	local nameText = select(7, frame:GetRegions())
	if not nameText then return false end
	
	local playerName = nameText:GetText()
	if not playerName then return false end
	
	-- Check caches in priority order
	-- 1. Party/Raid cache
	if self.PartyRaidCache and self.PartyRaidCache.EnhancedClassCheck then
		if self.PartyRaidCache:EnhancedClassCheck(frame) then
			return true
		end
	end
	
	-- 2. Guild cache  
	if self.GuildCache and self.GuildCache.EnhancedClassCheck then
		if self.GuildCache:EnhancedClassCheck(frame) then
			return true
		end
	end
	
	-- 3. Recently seen cache
	if self.RecentlySeenCache and self.RecentlySeenCache.EnhancedClassCheck then
		if self.RecentlySeenCache:EnhancedClassCheck(frame) then
			return true
		end
	end
	
	return false
end

function NotPlater:PrepareFrame(frame)
	local threatGlow, healthBorder, castBorder, castNoStop, spellIcon, highlightTexture, nameText, levelText, dangerSkull, bossIcon, raidIcon = frame:GetRegions()
	local health, cast = frame:GetChildren()

	-- Hooks and creation (only once that way settings can be applied while frame is visible)
	if not frame.npHooked then
		frame.npHooked = true

		frame.nameText, frame.levelText, frame.bossIcon, frame.raidIcon = nameText, levelText, bossIcon, raidIcon
		frame.highlightTexture = frame:CreateTexture(nil, "ARTWORK")

		-- Hide default border
		healthBorder:Hide()
		threatGlow:SetTexCoord(0, 0, 0, 0)
		castNoStop:SetTexCoord(0, 0, 0, 0)
		dangerSkull:SetTexCoord(0, 0, 0, 0)
		highlightTexture:SetTexCoord(0, 0, 0, 0)

		-- Store references to default cast elements for easy hiding
		frame.defaultCast = cast
		frame.defaultCastBorder = castBorder
		frame.defaultSpellIcon = spellIcon

		-- Construct everything
		self:ConstructHealthBar(frame, health)
		self:ConstructThreatComponents(frame.healthBar)
		self:ConstructCastBar(frame)
		self:ConstructTarget(frame)

		-- Hide old healthbar
		health:Hide()
    
		self:HookScript(frame, "OnShow", function(self)
			-- Force clear ALL cached data when showing
			self.unitClass = nil
			self.unitClassFromCache = nil
			self.recentlySeen = nil
			self.guildMember = nil
			self.partyRaidMember = nil
			self.lastCheckedName = nil
			
			-- Get the current nameplate name
			local nameText = select(7, self:GetRegions())
			local playerName = nameText and nameText:GetText()
			
			if NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: OnShow for: " .. (playerName or "unknown"))
			end
			
			-- Immediate cache check on nameplate show
			if playerName and NotPlater.db.profile.threat.nameplateColors.general.useClassColors then
				-- Check caches in priority order
				local foundClass = false
				
				-- 1. Party/Raid cache (most immediate)
				if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.EnhancedClassCheck then
					foundClass = NotPlater.PartyRaidCache:EnhancedClassCheck(self)
				end
				
				-- 2. Guild cache
				if not foundClass and NotPlater.GuildCache and NotPlater.GuildCache.EnhancedClassCheck then
					foundClass = NotPlater.GuildCache:EnhancedClassCheck(self)
				end
				
				-- 3. Recently seen cache
				if not foundClass and NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.EnhancedClassCheck then
					foundClass = NotPlater.RecentlySeenCache:EnhancedClassCheck(self)
					if foundClass and NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: OnShow found " .. playerName .. " in Recently Seen Cache")
					end
				end
				
				-- Apply colors immediately if found
				if self.unitClass and self.healthBar then
					-- Force the color application
					self.healthBar:SetStatusBarColor(self.unitClass.r, self.unitClass.g, self.unitClass.b, 1)
					
					-- Store the name we checked so we can verify in OnUpdate
					self.lastCheckedName = playerName
					
					if NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99NotPlater|r: OnShow applied color for %s: r=%.2f g=%.2f b=%.2f", 
							playerName, self.unitClass.r, self.unitClass.g, self.unitClass.b))
					end
				else
					if NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: OnShow no class found for: " .. playerName)
					end
				end
			end
			
			NotPlater:CastBarOnShow(self)
			NotPlater:HealthBarOnShow(health)
			NotPlater:StackingCheck(self)
			NotPlater:ThreatComponentsOnShow(self)
			NotPlater:TargetCheck(self)
			self.targetChanged = true
		end)
		
		-- Add OnHide to clear data
		self:HookScript(frame, "OnHide", function(self)
			-- Clear all class data when nameplate hides
			self.unitClass = nil
			self.unitClassFromCache = nil
			self.recentlySeen = nil
			self.guildMember = nil  
			self.partyRaidMember = nil
			self.wasTarget = nil
			
			if NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
				local nameText = select(7, self:GetRegions())
				if nameText then
					local playerName = nameText:GetText()
					DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: OnHide cleared data for: " .. (playerName or "unknown"))
				end
			end
		end)

		-- Simple OnUpdate that continuously hides default cast elements
		self:HookScript(frame, 'OnUpdate', function(self, elapsed)
			-- Always hide default cast elements when NotPlater castbar is enabled
			if NotPlater.db.profile.castBar.statusBar.general.enable then
				if self.defaultCast and self.defaultCast:IsShown() then
					self.defaultCast:Hide()
				end
				if self.defaultCastBorder and self.defaultCastBorder:IsShown() then
					self.defaultCastBorder:Hide()
				end
				if self.defaultSpellIcon and self.defaultSpellIcon:IsShown() then
					self.defaultSpellIcon:Hide()
				end
			end
			
			if not self.targetCheckElapsed then self.targetCheckElapsed = 0 end
			self.targetCheckElapsed = self.targetCheckElapsed + elapsed
			
			-- Only do expensive operations every 0.1 seconds
			if self.targetCheckElapsed >= 0.1 then
				local isTarget = NotPlater:IsTarget(self)
				
				-- Early exit if frame isn't shown
				if not self:IsShown() then
					return
				end
				
				if self.targetChanged then
					NotPlater:TargetCheck(self)
					self.targetChanged = nil
				end
				
				-- Only do class checking if we need class colors and don't already have a class
				-- IMPORTANT: Check if we already have unitClass to avoid overriding cache colors
				if NotPlater.db.profile.threat.nameplateColors.general.useClassColors and not self.unitClass then
					local nameText = select(7, self:GetRegions())
					local playerName = nameText and nameText:GetText()
					
					-- Debug logging
					if playerName and NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: OnUpdate checking for: " .. playerName .. " (unitClass is nil)")
					end
					
					-- Try party/raid cache first (most immediate)
					local foundClass = false
					if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.EnhancedClassCheck then
						foundClass = NotPlater.PartyRaidCache:EnhancedClassCheck(self)
					end
					-- If not found in party/raid, try guild cache
					if not foundClass and NotPlater.GuildCache and NotPlater.GuildCache.EnhancedClassCheck then
						foundClass = NotPlater.GuildCache:EnhancedClassCheck(self)
					end
					-- Try recently seen cache
					if not foundClass and NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.EnhancedClassCheck then
						foundClass = NotPlater.RecentlySeenCache:EnhancedClassCheck(self)
					end
					-- Finally fallback to regular class check
					if not foundClass then
						NotPlater:ClassCheck(self)
					end
					
					-- Apply class colors if we found a class
					if self.unitClass and frame.healthBar then
						frame.healthBar:SetStatusBarColor(self.unitClass.r, self.unitClass.g, self.unitClass.b, 1)
						
						if playerName and NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
							DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99NotPlater|r: OnUpdate applied color for %s: r=%.2f g=%.2f b=%.2f", 
								playerName, self.unitClass.r, self.unitClass.g, self.unitClass.b))
						end
					end
				elseif self.unitClass and frame.healthBar then
					-- We already have class colors, just make sure they're applied
					-- This handles the case where the health bar might have been reset
					local currentR, currentG, currentB = frame.healthBar:GetStatusBarColor()
					if math.abs(currentR - self.unitClass.r) > 0.01 or 
					   math.abs(currentG - self.unitClass.g) > 0.01 or 
					   math.abs(currentB - self.unitClass.b) > 0.01 then
						-- Color doesn't match, reapply
						frame.healthBar:SetStatusBarColor(self.unitClass.r, self.unitClass.g, self.unitClass.b, 1)
						
						if NotPlater.db.profile.recentlySeenCache and NotPlater.db.profile.recentlySeenCache.advanced.debugMode then
							local nameText = select(7, self:GetRegions())
							local playerName = nameText and nameText:GetText()
							DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99NotPlater|r: OnUpdate reapplied color for %s", playerName or "unknown"))
						end
					end
				end
				
				-- Set target/target text
				NotPlater:SetTargetTargetText(self)
				
				-- Handle alpha changes
				if isTarget then
					self:SetAlpha(1)
				elseif NotPlater.db.profile.target.general.nonTargetAlpha.enable then
					self:SetAlpha(NotPlater.db.profile.target.general.nonTargetAlpha.opacity)
				end
				
				self.targetCheckElapsed = 0
			end
			
			-- Handle level text visibility (this can be checked more frequently as it's cheap)
			if NotPlater.db.profile.levelText.general.enable then
				if not levelText:IsShown() then
					levelText:Show()
				end
				levelText:SetAlpha(NotPlater.db.profile.levelText.general.opacity)
			else
				if levelText:IsShown() then
					levelText:Hide()
				end
			end
		end)
	end
	
	-- Configure everything
	self:ConfigureThreatComponents(frame)
	self:ConfigureHealthBar(frame, health)
	self:ConfigureCastBar(frame)
	self:ConfigureStacking(frame)
	self:ConfigureGeneralisedIcon(bossIcon, frame.healthBar, self.db.profile.bossIcon)
	self:ConfigureGeneralisedIcon(raidIcon, frame.healthBar, self.db.profile.raidIcon)
	self:ConfigureLevelText(levelText, frame.healthBar)
	self:ConfigureNameText(nameText, frame.healthBar)
	self:ConfigureTarget(frame)
	self:TargetCheck(frame)
end

function NotPlater:HookFrames(...)
	local numArgs = select("#", ...)
	for i = 1, numArgs do
		local frame = select(i, ...)
		-- Skip frames we've already processed
		if not frames[frame] and not frame:GetName() then
			local region = frame:GetRegions()
			if region and region:GetObjectType() == "Texture" and region:GetTexture() == "Interface\\TargetingFrame\\UI-TargetingFrame-Flash" then
				frames[frame] = true
				self:PrepareFrame(frame)
			end
		end
	end
end

function NotPlater:Reload()
	-- Make sure frame exists before using it
	if not self.frame then
		self.frame = CreateFrame("Frame")
		self:SetupFrameScripts()
	end
	
	if self.db.profile.castBar.statusBar.general.enable then
		self:RegisterCastBarEvents(self.frame)
	else
		self:UnregisterCastBarEvents(self.frame)
	end

	if self.db.profile.threat.general.enableMouseoverUpdate then
		self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	else
		self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
	end

	for frame in pairs(frames) do
		self:PrepareFrame(frame)
	end
end

function NotPlater:PLAYER_TARGET_CHANGED()
	for frame in pairs(frames) do
		frame.targetChanged = true
	end
end

function NotPlater:ApplyUnitClassColor(frame)
    -- Helper to apply class colors to a frame
    if frame.unitClass and frame.healthBar then
        frame.healthBar:SetStatusBarColor(
            frame.unitClass.r,
            frame.unitClass.g,
            frame.unitClass.b,
            1
        )
        return true
    end
    return false
end

-- WITH THE NEW VERSION that adds caching:
function NotPlater:ClassCheck(frame)
    if frame.unitClass then return end
    
    -- Check if we should skip NPCs when playersOnly is enabled
    local skipNPCs = self.db.profile.threat.nameplateColors.general.useClassColors and 
                     self.db.profile.threat.nameplateColors.general.playersOnly
    
    local nameText, levelText = select(7, frame:GetRegions())
    if not nameText or not levelText then return end
    
    local name = nameText:GetText()
    local level = levelText:GetText()
    local healthValue = frame.healthBar:GetValue()
    
    if not name or not level then return end
    
    -- Variables to store found class info
    local foundClass = nil
    local foundClassFileName = nil
    local foundLevel = nil
    local foundUnit = nil
    
    -- Check target first as it's most common and fastest
    if self:IsTarget(frame) then
        if not (skipNPCs and not UnitIsPlayer("target")) then
            local className, classFileName = UnitClass("target")
            if classFileName and RAID_CLASS_COLORS[classFileName] then
                frame.unitClass = RAID_CLASS_COLORS[classFileName]
                foundClass = className
                foundClassFileName = classFileName
                foundLevel = UnitLevel("target")
                foundUnit = "target"
            end
        end
    end

    -- Check group members if in group
    if not frame.unitClass then
        local group = self.raid or self.party
        if group then
            for gMember, unitID in pairs(group) do
                local targetString = unitID .. "-target"
                if name == UnitName(targetString) and level == tostring(UnitLevel(targetString)) and healthValue == UnitHealth(targetString) then
                    if not (skipNPCs and not UnitIsPlayer(targetString)) then
                        local className, classFileName = UnitClass(targetString)
                        if classFileName and RAID_CLASS_COLORS[classFileName] then
                            frame.unitClass = RAID_CLASS_COLORS[classFileName]
                            foundClass = className
                            foundClassFileName = classFileName
                            foundLevel = UnitLevel(targetString)
                            foundUnit = targetString
                        end
                    end
                    break
                end
            end
        end
    end
    
    -- Check mouseover
    if not frame.unitClass then
        if name == UnitName("mouseover") and level == tostring(UnitLevel("mouseover")) and healthValue == UnitHealth("mouseover") then
            if not (skipNPCs and not UnitIsPlayer("mouseover")) then
                local className, classFileName = UnitClass("mouseover")
                if classFileName and RAID_CLASS_COLORS[classFileName] then
                    frame.unitClass = RAID_CLASS_COLORS[classFileName]
                    foundClass = className
                    foundClassFileName = classFileName
                    foundLevel = UnitLevel("mouseover")
                    foundUnit = "mouseover"
                end
            end
        end
    end
    
    -- Check focus last
    if not frame.unitClass then
        if name == UnitName("focus") and level == tostring(UnitLevel("focus")) and healthValue == UnitHealth("focus") then
            if not (skipNPCs and not UnitIsPlayer("focus")) then
                local className, classFileName = UnitClass("focus")
                if classFileName and RAID_CLASS_COLORS[classFileName] then
                    frame.unitClass = RAID_CLASS_COLORS[classFileName]
                    foundClass = className
                    foundClassFileName = classFileName
                    foundLevel = UnitLevel("focus")
                    foundUnit = "focus"
                end
            end
        end
    end
    
    -- If we found a player's class, add them to recently seen cache AND apply color
    if foundClass and foundClassFileName and foundUnit then
        -- Store the class on the frame
        if not frame.unitClass then
            frame.unitClass = RAID_CLASS_COLORS[foundClassFileName]
        end
        
        -- Only add players (not NPCs) to the cache
        if UnitIsPlayer(foundUnit) then
            if self.RecentlySeenCache and self.RecentlySeenCache.AddPlayer then
                self.RecentlySeenCache:AddPlayer(name, foundClass, foundClassFileName, foundLevel)
            end
        end
        
        -- Apply color immediately
        self:ApplyUnitClassColor(frame)
    end
end

function NotPlater:UPDATE_MOUSEOVER_UNIT()
	if UnitCanAttack("player", "mouseover") and not UnitIsDeadOrGhost("mouseover") and UnitAffectingCombat("mouseover") then
		local mouseOverGuid = UnitGUID("mouseover")
		local targetGuid = UnitGUID("target")
		for frame in pairs(frames) do
			if frame:IsShown() then
				if mouseOverGuid == targetGuid then
					if self:IsTarget(frame) then
						self:MouseoverThreatCheck(frame.healthBar, targetGuid)
						frame.highlightTexture:Show()
					end
				else
					local nameText, levelText = select(7, frame:GetRegions())
					local name = nameText:GetText()
					local level = levelText:GetText()
					local _, healthMaxValue = frame.healthBar:GetMinMaxValues()
					local healthValue = frame.healthBar:GetValue()
					if name == UnitName("mouseover") and level == tostring(UnitLevel("mouseover")) and healthValue == UnitHealth("mouseover") and healthValue ~= healthMaxValue then
						self:MouseoverThreatCheck(frame.healthBar, mouseOverGuid)
					end
				end
			end
		end
	end
end

-- NOTE: Frame scripts are now set up in SetupFrameScripts() function called from OnInitialize()