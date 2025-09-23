-- modules/sct.lua
-- Scrolling Combat Text module for NotPlater
-- Fixed version with proper GUID tracking

if not NotPlater then return end

local SCT = {}
NotPlater.SCT = SCT

-- Local references for performance
local CreateFrame = CreateFrame
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitExists = UnitExists
local math_floor = math.floor
local math_pow = math.pow
local math_random = math.random
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local pairs = pairs
local ipairs = ipairs

-- Animation tracking
local animating = {}
local fontStringCache = {}
local frameCounter = 0

-- GUID to nameplate tracking
local guidToNameplate = {}
local nameplateUpdateTimer = 0

-- Constants
local ANIMATION_VERTICAL_DISTANCE = 75
local ANIMATION_ARC_X_MIN = 50
local ANIMATION_ARC_X_MAX = 150
local ANIMATION_ARC_Y_TOP_MIN = 10
local ANIMATION_ARC_Y_TOP_MAX = 50
local ANIMATION_ARC_Y_BOTTOM_MIN = 10
local ANIMATION_ARC_Y_BOTTOM_MAX = 50
local ANIMATION_RAINFALL_X_MAX = 75
local ANIMATION_RAINFALL_Y_MIN = 50
local ANIMATION_RAINFALL_Y_MAX = 100
local ANIMATION_RAINFALL_Y_START_MIN = 5
local ANIMATION_RAINFALL_Y_START_MAX = 15

-- Damage tracking for sizing
local numDamageEvents = 0
local lastDamageEventTime
local runningAverageDamageEvents = 0
local SMALL_HIT_EXPIRY_WINDOW = 30
local SMALL_HIT_MULTIPIER = 0.5

-- Direction tracking
local arcDirection = 1

-- Spell info
local AutoAttack = GetSpellInfo(6603) or "Auto Attack"
local AutoShot = GetSpellInfo(75) or "Auto Shot"

-- Color definitions
local DAMAGE_TYPE_COLORS = {
    [1] = "FFFF00", -- Physical
    [2] = "FFE680", -- Holy
    [4] = "FF8000", -- Fire
    [8] = "4DFF4D", -- Nature
    [16] = "80FFFF", -- Frost
    [32] = "8080FF", -- Shadow
    [64] = "FF80FF", -- Arcane
    ["pet"] = "CC8400"
}

local MISS_EVENT_STRINGS = {
    ["ABSORB"] = "Absorbed",
    ["BLOCK"] = "Blocked",
    ["DEFLECT"] = "Deflected",
    ["DODGE"] = "Dodged",
    ["EVADE"] = "Evaded",
    ["IMMUNE"] = "Immune",
    ["MISS"] = "Miss",
    ["PARRY"] = "Parried",
    ["REFLECT"] = "Reflected",
    ["RESIST"] = "Resisted"
}

-- Initialize SCT settings
function SCT:InitializeDefaults()
    if not NotPlater.db.profile.sct then
        NotPlater.db.profile.sct = {
            general = {
                enable = true,
                debug = false,
            },
            display = {
                truncate = true,
                truncateLetter = true,
                commaSeparate = true,
                showIcon = true,
                iconScale = 1,
                displayOverkill = false,
                showHeals = false,
                showPersonal = true,
            },
            font = {
                name = "Arial Narrow",
                size = 20,
                outline = "OUTLINE",
                shadow = false,
            },
            position = {
                xOffset = 0,
                yOffset = 0,
                personalXOffset = 0,
                personalYOffset = -100,
            },
            animations = {
                speed = 1,
                ability = "fountain",
                crit = "verticalUp",
                miss = "verticalUp",
                autoattack = "fountain",
                autoattackcrit = "verticalUp",
                personal = {
                    normal = "rainfall",
                    crit = "verticalUp",
                    miss = "verticalUp",
                }
            },
            colors = {
                damageColor = true,
                defaultColor = "ffff00",
                personalColor = "ff0000",
            },
            sizing = {
                crits = true,
                critsScale = 1.5,
                miss = false,
                missScale = 1.5,
                smallHits = true,
                smallHitsScale = 0.66,
                smallHitsHide = false,
            },
            formatting = {
                alpha = 1,
            },
            offTarget = {
                enable = true,
                size = 15,
                alpha = 0.5,
            },
        }
    end
end

-- Debug print
function SCT:Debug(msg)
    if NotPlater.db.profile.sct.general.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater SCT Debug|r: " .. tostring(msg))
    end
end

-- Update GUID mappings
function SCT:UpdateGUIDMappings()
    -- Clear old mappings
    for guid in pairs(guidToNameplate) do
        guidToNameplate[guid] = nil
    end
    
    -- Update mappings from NotPlater frames
    if NotPlater.frames then
        for frame in pairs(NotPlater.frames) do
            if frame:IsShown() and frame.unitGUID then
                guidToNameplate[frame.unitGUID] = frame
            end
        end
    end
    
    -- Try to get GUIDs for visible units
    local unitsToCheck = {"target", "mouseover", "focus"}
    
    -- Add party/raid targets
    if UnitInRaid("player") then
        for i = 1, GetNumRaidMembers() do
            table.insert(unitsToCheck, "raid" .. i .. "-target")
        end
    elseif UnitInParty("player") then
        for i = 1, GetNumPartyMembers() do
            table.insert(unitsToCheck, "party" .. i .. "-target")
        end
    end
    
    -- Check each unit and try to match with nameplates
    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid and not guidToNameplate[guid] then
                -- Try to find matching nameplate
                if NotPlater.frames then
                    for frame in pairs(NotPlater.frames) do
                        if frame:IsShown() then
                            local nameText, levelText = select(7, frame:GetRegions())
                            if nameText and levelText then
                                local name = nameText:GetText()
                                local level = levelText:GetText()
                                if name == UnitName(unit) and level == tostring(UnitLevel(unit)) then
                                    frame.unitGUID = guid
                                    guidToNameplate[guid] = frame
                                    self:Debug("Mapped GUID " .. guid .. " to nameplate for " .. name)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Get nameplate by GUID (improved version)
function SCT:GetNameplateByGUID(guid)
    local playerGUID = UnitGUID("player")
    
    -- Check if it's the player
    if guid == playerGUID then
        return UIParent  -- Use UIParent for personal SCT
    end
    
    -- Check cached mapping first
    if guidToNameplate[guid] then
        local frame = guidToNameplate[guid]
        if frame and frame:IsShown() then
            return frame
        else
            -- Frame is no longer valid, remove from cache
            guidToNameplate[guid] = nil
        end
    end
    
    -- Try NotPlater's function
    if NotPlater.GetNameplateByGUID then
        local frame = NotPlater:GetNameplateByGUID(guid)
        if frame then
            guidToNameplate[guid] = frame
            return frame
        end
    end
    
    -- Manual search through frames
    if NotPlater.frames then
        for frame in pairs(NotPlater.frames) do
            if frame:IsShown() and frame.unitGUID == guid then
                guidToNameplate[guid] = frame
                return frame
            end
        end
    end
    
    self:Debug("No nameplate found for GUID: " .. tostring(guid))
    return nil
end

-- Font string management
function SCT:GetFontString()
    local fontString
    local fontStringFrame
    
    if #fontStringCache > 0 then
        fontString = table_remove(fontStringCache)
        fontStringFrame = fontString:GetParent()
    else
        frameCounter = frameCounter + 1
        fontStringFrame = CreateFrame("Frame", nil, UIParent)
        fontStringFrame:SetFrameStrata("HIGH")
        fontStringFrame:SetFrameLevel(frameCounter + 100)
        fontString = fontStringFrame:CreateFontString()
        fontString:SetParent(fontStringFrame)
    end
    
    local config = NotPlater.db.profile.sct
    local fontPath = NotPlater.SML:Fetch(NotPlater.SML.MediaType.FONT, config.font.name) or "Fonts\\FRIZQT__.TTF"
    fontString:SetFont(fontPath, config.font.size, config.font.outline)
    
    if config.font.shadow then
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowOffset(0, 0)
    end
    
    fontString:SetAlpha(1)
    fontString:SetDrawLayer("OVERLAY")
    fontString:SetText("")
    fontString:Show()
    
    -- Create icon if needed
    if config.display.showIcon then
        if not fontString.icon then
            fontString.icon = fontStringFrame:CreateTexture(nil, "OVERLAY")
            fontString.icon:SetTexCoord(0.062, 0.938, 0.062, 0.938)
        end
        fontString.icon:SetAlpha(1)
        fontString.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        fontString.icon:Hide()
    end
    
    return fontString
end

function SCT:RecycleFontString(fontString)
    fontString:SetAlpha(0)
    fontString:Hide()
    
    animating[fontString] = nil
    
    -- Clear all properties
    fontString.distance = nil
    fontString.arcTop = nil
    fontString.arcBottom = nil
    fontString.arcXDist = nil
    fontString.animation = nil
    fontString.animatingDuration = nil
    fontString.animatingStartTime = nil
    fontString.anchorFrame = nil
    fontString.guid = nil
    fontString.startHeight = nil
    fontString.pow = nil
    fontString.rainfallX = nil
    fontString.rainfallStartY = nil
    fontString.isPersonal = nil
    
    if fontString.icon then
        fontString.icon:ClearAllPoints()
        fontString.icon:SetAlpha(0)
        fontString.icon:Hide()
    end
    
    fontString:ClearAllPoints()
    
    table_insert(fontStringCache, fontString)
end

-- Animation paths
local function verticalPath(elapsed, duration, distance)
    local progress = elapsed / duration
    return 0, progress * distance
end

local function arcPath(elapsed, duration, xDist, yStart, yTop, yBottom)
    local progress = elapsed / duration
    local x = progress * xDist
    
    local a = -2 * yStart + 4 * yTop - 2 * yBottom
    local b = -3 * yStart + 4 * yTop - yBottom
    local y = -a * math_pow(progress, 2) + b * progress + yStart
    
    return x, y
end

-- Animation update
local function AnimationOnUpdate()
    if not next(animating) then
        SCT.animationFrame:SetScript("OnUpdate", nil)
        return
    end
    
    for fontString, _ in pairs(animating) do
        local elapsed = GetTime() - fontString.animatingStartTime
        if elapsed > fontString.animatingDuration then
            SCT:RecycleFontString(fontString)
        else
            local config = NotPlater.db.profile.sct
            local alpha = 1 - (elapsed / fontString.animatingDuration)
            fontString:SetAlpha(alpha * config.formatting.alpha)
            
            -- Pow effect for crits
            if fontString.pow and elapsed < fontString.animatingDuration / 6 then
                local size = fontString.startHeight * (1 + (1 - elapsed / (fontString.animatingDuration / 6)))
                fontString:SetTextHeight(size)
            end
            
            local xOffset, yOffset = 0, 0
            
            if fontString.animation == "verticalUp" then
                xOffset, yOffset = verticalPath(elapsed, fontString.animatingDuration, fontString.distance)
            elseif fontString.animation == "verticalDown" then
                xOffset, yOffset = verticalPath(elapsed, fontString.animatingDuration, -fontString.distance)
            elseif fontString.animation == "fountain" then
                xOffset, yOffset = arcPath(elapsed, fontString.animatingDuration, fontString.arcXDist, 0, fontString.arcTop, fontString.arcBottom)
            elseif fontString.animation == "rainfall" then
                _, yOffset = verticalPath(elapsed, fontString.animatingDuration, -fontString.distance)
                xOffset = fontString.rainfallX
                yOffset = yOffset + fontString.rainfallStartY
            end
            
            -- Check if anchor frame is still valid
            if fontString.anchorFrame and fontString.anchorFrame:IsShown() then
                -- For non-personal damage, check if we still have the right nameplate
                if not fontString.isPersonal and fontString.guid then
                    local currentNameplate = guidToNameplate[fontString.guid]
                    if currentNameplate and currentNameplate ~= fontString.anchorFrame then
                        -- Nameplate changed, update anchor
                        fontString.anchorFrame = currentNameplate
                    end
                end
                
                local baseXOffset = fontString.isPersonal and config.position.personalXOffset or config.position.xOffset
                local baseYOffset = fontString.isPersonal and config.position.personalYOffset or config.position.yOffset
                fontString:SetPoint("CENTER", fontString.anchorFrame, "CENTER", baseXOffset + xOffset, baseYOffset + yOffset)
            else
                SCT:RecycleFontString(fontString)
            end
        end
    end
end

-- Start animation
function SCT:Animate(fontString, anchorFrame, duration, animation, guid)
    local config = NotPlater.db.profile.sct
    
    fontString.animation = animation
    fontString.animatingDuration = duration / config.animations.speed
    fontString.animatingStartTime = GetTime()
    fontString.anchorFrame = anchorFrame
    fontString.guid = guid  -- Store GUID for tracking
    
    if animation == "verticalUp" or animation == "verticalDown" then
        fontString.distance = ANIMATION_VERTICAL_DISTANCE
    elseif animation == "fountain" then
        fontString.arcTop = math_random(ANIMATION_ARC_Y_TOP_MIN, ANIMATION_ARC_Y_TOP_MAX)
        fontString.arcBottom = -math_random(ANIMATION_ARC_Y_BOTTOM_MIN, ANIMATION_ARC_Y_BOTTOM_MAX)
        fontString.arcXDist = arcDirection * math_random(ANIMATION_ARC_X_MIN, ANIMATION_ARC_X_MAX)
        arcDirection = arcDirection * -1
    elseif animation == "rainfall" then
        fontString.distance = math_random(ANIMATION_RAINFALL_Y_MIN, ANIMATION_RAINFALL_Y_MAX)
        fontString.rainfallX = math_random(-ANIMATION_RAINFALL_X_MAX, ANIMATION_RAINFALL_X_MAX)
        fontString.rainfallStartY = math_random(ANIMATION_RAINFALL_Y_START_MIN, ANIMATION_RAINFALL_Y_START_MAX)
    end
    
    animating[fontString] = true
    
    if not self.animationFrame then
        self.animationFrame = CreateFrame("Frame")
    end
    self.animationFrame:SetScript("OnUpdate", AnimationOnUpdate)
end

-- Format number
function SCT:FormatNumber(amount)
    local config = NotPlater.db.profile.sct
    
    if config.display.truncate then
        if amount >= 1000000 then
            return config.display.truncateLetter and string_format("%.1fM", amount / 1000000) or string_format("%.0f", amount / 1000)
        elseif amount >= 10000 then
            return config.display.truncateLetter and string_format("%.0fk", amount / 1000) or string_format("%.0f", amount / 1000)
        elseif amount >= 1000 then
            return config.display.truncateLetter and string_format("%.1fk", amount / 1000) or string_format("%.1f", amount / 1000)
        end
    end
    
    if config.display.commaSeparate and amount >= 1000 then
        local formatted = tostring(math_floor(amount))
        return formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
    
    return tostring(amount)
end

-- Color text
function SCT:ColorText(text, school, spellName, isPersonal)
    local config = NotPlater.db.profile.sct
    
    if config.colors.damageColor and DAMAGE_TYPE_COLORS[school] then
        return string_format("\124cff%s%s\124r", DAMAGE_TYPE_COLORS[school], text)
    else
        local color = isPersonal and config.colors.personalColor or config.colors.defaultColor
        return string_format("\124cff%s%s\124r", color, text)
    end
end

-- Display damage event
function SCT:DamageEvent(destGUID, spellName, amount, overkill, school, crit, spellId, isHeal)
    local config = NotPlater.db.profile.sct
    
    if not config.general.enable then return end
    if isHeal and not config.display.showHeals then return end
    
    local playerGUID = UnitGUID("player")
    local isPersonal = destGUID == playerGUID
    
    if isPersonal and not config.display.showPersonal then return end
    
    -- Update mappings before getting nameplate
    self:UpdateGUIDMappings()
    
    local nameplate = self:GetNameplateByGUID(destGUID)
    if not nameplate and not isPersonal then 
        self:Debug("No nameplate found for damage to " .. (UnitName("target") or "unknown"))
        return 
    end
    
    if isPersonal and not nameplate then
        nameplate = UIParent
    end
    
    local isTarget = UnitExists("target") and UnitGUID("target") == destGUID
    
    -- Determine animation
    local animation
    if isPersonal then
        animation = crit and config.animations.personal.crit or config.animations.personal.normal
    else
        local autoattack = spellName == AutoAttack or spellName == AutoShot or spellName == "Auto Attack"
        if autoattack and crit then
            animation = config.animations.autoattackcrit
        elseif autoattack then
            animation = config.animations.autoattack
        elseif crit then
            animation = config.animations.crit
        else
            animation = config.animations.ability
        end
    end
    
    if animation == "disabled" then return end
    
    -- Format text
    local text = self:FormatNumber(amount)
    if overkill and overkill > 0 and config.display.displayOverkill then
        text = text .. " (Overkill: " .. overkill .. ")"
    end
    text = self:ColorText(text, school, spellName, isPersonal)
    
    -- Determine size
    local size = config.font.size
    local alpha = config.formatting.alpha
    
    if not isTarget and config.offTarget.enable and not isPersonal then
        size = config.offTarget.size
        alpha = config.offTarget.alpha
    end
    
    -- Apply sizing modifiers
    if config.sizing.crits and crit and not isPersonal then
        size = size * config.sizing.critsScale
    end
    
    -- Small hit detection
    if config.sizing.smallHits and not isPersonal then
        if not lastDamageEventTime or (lastDamageEventTime + SMALL_HIT_EXPIRY_WINDOW < GetTime()) then
            numDamageEvents = 0
            runningAverageDamageEvents = 0
        end
        
        runningAverageDamageEvents = ((runningAverageDamageEvents * numDamageEvents) + amount) / (numDamageEvents + 1)
        numDamageEvents = numDamageEvents + 1
        lastDamageEventTime = GetTime()
        
        local threshold = crit and (amount / 2) or amount
        if threshold < SMALL_HIT_MULTIPIER * runningAverageDamageEvents then
            if config.sizing.smallHitsHide then
                return
            else
                size = size * config.sizing.smallHitsScale
            end
        end
    end
    
    self:Debug(string.format("Showing %d %s on %s", amount, spellName, isPersonal and "player" or "enemy"))
    self:DisplayText(nameplate, text, size, alpha, animation, spellId, crit and not isPersonal, spellName, isPersonal, destGUID)
end

-- Display miss event
function SCT:MissEvent(destGUID, spellName, missType, spellId)
    local config = NotPlater.db.profile.sct
    
    if not config.general.enable then return end
    
    local playerGUID = UnitGUID("player")
    local isPersonal = destGUID == playerGUID
    
    if isPersonal and not config.display.showPersonal then return end
    
    -- Update mappings before getting nameplate
    self:UpdateGUIDMappings()
    
    local nameplate = self:GetNameplateByGUID(destGUID)
    if not nameplate and not isPersonal then return end
    
    if isPersonal and not nameplate then
        nameplate = UIParent
    end
    
    local isTarget = UnitExists("target") and UnitGUID("target") == destGUID
    
    local animation = isPersonal and config.animations.personal.miss or config.animations.miss
    if animation == "disabled" then return end
    
    local text = MISS_EVENT_STRINGS[missType] or "Miss"
    local color = isPersonal and config.colors.personalColor or config.colors.defaultColor
    text = string_format("\124cff%s%s\124r", color, text)
    
    local size = config.font.size
    local alpha = config.formatting.alpha
    
    if not isTarget and config.offTarget.enable and not isPersonal then
        size = config.offTarget.size
        alpha = config.offTarget.alpha
    end
    
    if config.sizing.miss and not isPersonal then
        size = size * config.sizing.missScale
    end
    
    self:DisplayText(nameplate, text, size, alpha, animation, spellId, true, spellName, isPersonal, destGUID)
end

-- Display text
function SCT:DisplayText(nameplate, text, size, alpha, animation, spellId, pow, spellName, isPersonal, guid)
    if not nameplate then return end
    
    local fontString = self:GetFontString()
    local config = NotPlater.db.profile.sct
    
    fontString:SetText(text)
    fontString:SetFont(
        NotPlater.SML:Fetch(NotPlater.SML.MediaType.FONT, config.font.name) or "Fonts\\FRIZQT__.TTF",
        size,
        config.font.outline
    )
    
    if config.font.shadow then
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowOffset(0, 0)
    end
    
    fontString.startHeight = fontString:GetStringHeight()
    fontString.pow = pow
    fontString.isPersonal = isPersonal
    
    -- Set icon if available
    if config.display.showIcon and spellId and fontString.icon then
        local _, _, texture = GetSpellInfo(spellId)
        if not texture and spellName then
            _, _, texture = GetSpellInfo(spellName)
        end
        
        if texture then
            fontString.icon:SetTexture(texture)
            fontString.icon:SetSize(size * config.display.iconScale, size * config.display.iconScale)
            fontString.icon:SetPoint("RIGHT", fontString, "LEFT", -2, 0)
            fontString.icon:SetAlpha(alpha)
            fontString.icon:Show()
        end
    end
    
    self:Animate(fontString, nameplate, 1.5, animation, guid)
end

-- Combat log event handler
function SCT:COMBAT_LOG_EVENT_UNFILTERED(_, _, eventType, srcGUID, srcName, srcFlags, destGUID, destName, destFlags, ...)
    local playerGUID = UnitGUID("player")
    
    -- Process outgoing damage from player
    if srcGUID == playerGUID then
        if eventType == "SWING_DAMAGE" then
            local amount, overkill, _, _, _, _, critical = ...
            self:DamageEvent(destGUID, AutoAttack or "Auto Attack", amount, overkill, 1, critical, 6603, false)
            
        elseif eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "RANGE_DAMAGE" then
            local spellId, spellName, school, amount, overkill, _, _, _, _, critical = ...
            self:DamageEvent(destGUID, spellName, amount, overkill, school, critical, spellId, false)
            
        elseif eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
            local spellId, spellName, school, amount, overheal, _, critical = ...
            self:DamageEvent(destGUID, spellName, amount, overheal, school, critical, spellId, true)
            
        elseif eventType == "SWING_MISSED" then
            local missType = ...
            self:MissEvent(destGUID, AutoAttack or "Auto Attack", missType, 6603)
            
        elseif eventType == "SPELL_MISSED" or eventType == "SPELL_PERIODIC_MISSED" or eventType == "RANGE_MISSED" then
            local spellId, spellName, school, missType = ...
            self:MissEvent(destGUID, spellName, missType, spellId)
        end
    end
    
    -- Process incoming damage to player
    if destGUID == playerGUID and NotPlater.db.profile.sct.display.showPersonal then
        if eventType == "SWING_DAMAGE" then
            local amount, overkill, _, _, _, _, critical = ...
            self:DamageEvent(destGUID, "Melee", amount, overkill, 1, critical, 6603, false)
            
        elseif eventType:find("_DAMAGE") then
            local spellId, spellName, school, amount, overkill, _, _, _, _, critical = ...
            if spellId and amount then
                self:DamageEvent(destGUID, spellName or "Unknown", amount, overkill or 0, school or 1, critical, spellId, false)
            end
            
        elseif eventType:find("_HEAL") and NotPlater.db.profile.sct.display.showHeals then
            local spellId, spellName, school, amount, overheal, _, critical = ...
            if spellId and amount then
                self:DamageEvent(destGUID, spellName or "Heal", amount, overheal or 0, school or 2, critical, spellId, true)
            end
            
        elseif eventType:find("_MISSED") then
            local spellId, spellName, school, missType = ...
            if missType then
                self:MissEvent(destGUID, spellName or "Attack", missType, spellId or 0)
            end
        end
    end
end

-- Test mode
function SCT:TestMode()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: SCT Test mode")
    
    local testGUID = UnitGUID("target")
    if not testGUID then
        testGUID = UnitGUID("player")
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: No target selected, testing personal SCT")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Testing on current target")
    end
    
    local testEvents = {
        {amount = 1234, crit = false, school = 1, spell = "Test Hit"},
        {amount = 5678, crit = true, school = 4, spell = "Test Crit"},
        {amount = 999, crit = false, school = 8, spell = "Test DoT"},
        {missType = "DODGE", spell = "Test Dodge"},
        {missType = "PARRY", spell = "Test Parry"},
    }
    
    for i, event in ipairs(testEvents) do
        C_Timer.After(i * 0.3, function()
            if event.missType then
                self:MissEvent(testGUID, event.spell, event.missType, 12345)
            else
                self:DamageEvent(testGUID, event.spell, event.amount, 0, event.school, event.crit, 12345, false)
            end
        end)
    end
end

-- Initialize
function SCT:Initialize()
    self:InitializeDefaults()
    
    -- Register for combat log
    NotPlater.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Hook the combat log handler
    local oldHandler = NotPlater.frame:GetScript("OnEvent")
    NotPlater.frame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            SCT:COMBAT_LOG_EVENT_UNFILTERED(...)
        end
        if oldHandler then
            oldHandler(self, event, ...)
        end
    end)
    
    -- Update GUID mappings periodically
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        nameplateUpdateTimer = nameplateUpdateTimer + elapsed
        if nameplateUpdateTimer >= 0.5 then  -- Update every 0.5 seconds
            nameplateUpdateTimer = 0
            SCT:UpdateGUIDMappings()
        end
    end)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: SCT module initialized")
end

-- Initialize when ready
C_Timer.After(1, function()
    if NotPlater and NotPlater.SCT then
        NotPlater.SCT:Initialize()
    end
end)