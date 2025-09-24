-- modules/sct.lua
-- Scrolling Combat Text module for NotPlater
-- Fixed version with working pet damage and proper icon support

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
local CombatLog_Object_IsA = CombatLog_Object_IsA
local COMBATLOG_FILTER_MY_PET = COMBATLOG_FILTER_MY_PET

-- Animation tracking
local animating = {}
local fontStringCache = {}
local frameCounter = 0

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
local Shoot = GetSpellInfo(5019) or "Shoot"

-- Color definitions
local DAMAGE_TYPE_COLORS = {
    [1] = "FFFF00", -- Physical
    [2] = "FFE680", -- Holy
    [4] = "FF8000", -- Fire
    [8] = "4DFF4D", -- Nature
    [16] = "80FFFF", -- Frost
    [32] = "8080FF", -- Shadow
    [64] = "FF80FF", -- Arcane
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
                commaSeparate = false,
                showIcon = true,
                iconScale = 1,
                displayOverkill = false,
                showHeals = false,
                showPersonal = true,
                showPetDamage = true,  -- Pet damage enabled by default
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
                petColor = "CC8400",  -- Orange for pet damage
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
    
    -- Ensure pet settings exist for older configs
    if NotPlater.db.profile.sct.display.showPetDamage == nil then
        NotPlater.db.profile.sct.display.showPetDamage = true
    end
    if not NotPlater.db.profile.sct.colors.petColor then
        NotPlater.db.profile.sct.colors.petColor = "CC8400"
    end
end

-- Debug print
function SCT:Debug(msg)
    if NotPlater.db.profile.sct.general.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater SCT Debug|r: " .. tostring(msg))
    end
end

-- Check if source is player's pet using WotLK API
function SCT:IsMyPet(srcFlags)
    -- Use the WotLK CombatLog API to check if it's our pet
    return CombatLog_Object_IsA(srcFlags, COMBATLOG_FILTER_MY_PET)
end

-- Get pet's GUID
function SCT:GetPetGUID()
    if UnitExists("pet") then
        return UnitGUID("pet")
    end
    return nil
end

-- Get nameplate by GUID
function SCT:GetNameplateByGUID(guid)
    local playerGUID = UnitGUID("player")
    
    -- Check if it's the player
    if guid == playerGUID then
        return UIParent
    end
    
    -- First try to find nameplate through current target
    if UnitExists("target") and UnitGUID("target") == guid then
        -- Look for the target's nameplate
        if NotPlater.frames then
            for frame in pairs(NotPlater.frames) do
                if frame:IsShown() and NotPlater:IsTarget(frame) then
                    self:Debug("Found nameplate via target check")
                    return frame
                end
            end
        end
    end
    
    -- Try NotPlater's built-in function
    if NotPlater.GetNameplateByGUID then
        local frame = NotPlater:GetNameplateByGUID(guid)
        if frame then
            self:Debug("Found nameplate via NotPlater:GetNameplateByGUID")
            return frame
        end
    end
    
    -- Manual search through all visible nameplates
    if NotPlater.frames then
        local targetName = nil
        local targetLevel = nil
        
        -- Get the name/level for this GUID from known units
        local unitsToCheck = {"target", "mouseover", "focus", "pet", "pettarget"}
        
        -- Add party/raid targets
        if UnitInRaid("player") then
            for i = 1, GetNumRaidMembers() do
                table.insert(unitsToCheck, "raid" .. i .. "-target")
                table.insert(unitsToCheck, "raidpet" .. i .. "-target")
            end
        elseif UnitInParty("player") then
            for i = 1, GetNumPartyMembers() do
                table.insert(unitsToCheck, "party" .. i .. "-target")
                table.insert(unitsToCheck, "partypet" .. i .. "-target")
            end
        end
        
        -- Find the name/level for this GUID
        for _, unit in ipairs(unitsToCheck) do
            if UnitExists(unit) and UnitGUID(unit) == guid then
                targetName = UnitName(unit)
                targetLevel = tostring(UnitLevel(unit))
                self:Debug(string.format("Found unit %s with name %s level %s", unit, targetName or "nil", targetLevel or "nil"))
                break
            end
        end
        
        -- Now search nameplates for this name/level combo
        if targetName and targetLevel then
            for frame in pairs(NotPlater.frames) do
                if frame:IsShown() then
                    local nameText, levelText = select(7, frame:GetRegions())
                    if nameText and levelText then
                        local name = nameText:GetText()
                        local level = levelText:GetText()
                        
                        if name == targetName and level == targetLevel then
                            self:Debug("Found nameplate via name/level match: " .. name)
                            return frame
                        end
                    end
                end
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
    if not fontString.icon then
        fontString.icon = fontStringFrame:CreateTexture(nil, "OVERLAY")
        fontString.icon:SetTexCoord(0.062, 0.938, 0.062, 0.938)
    end
    fontString.icon:SetAlpha(1)
    fontString.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    fontString.icon:Hide()
    
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
    fontString.guid = guid
    
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

-- Color text (updated for pet damage)
function SCT:ColorText(text, school, spellName, isPersonal, isPet)
    local config = NotPlater.db.profile.sct
    
    if isPet then
        -- Use pet color for pet damage
        return string_format("\124cff%s%s\124r", config.colors.petColor or "CC8400", text)
    elseif config.colors.damageColor and DAMAGE_TYPE_COLORS[school] then
        return string_format("\124cff%s%s\124r", DAMAGE_TYPE_COLORS[school], text)
    else
        local color = isPersonal and config.colors.personalColor or config.colors.defaultColor
        return string_format("\124cff%s%s\124r", color, text)
    end
end

-- Display damage event
function SCT:DamageEvent(destGUID, spellName, amount, overkill, school, crit, spellId, isHeal, isPet)
    local config = NotPlater.db.profile.sct
    
    if not config.general.enable then return end
    if isHeal and not config.display.showHeals then return end
    if isPet and not config.display.showPetDamage then return end
    
    local playerGUID = UnitGUID("player")
    local isPersonal = destGUID == playerGUID
    
    if isPersonal and not config.display.showPersonal then return end
    
    self:Debug(string_format("DamageEvent: %s took %d from %s (school:%d, spellId:%d)%s", 
        tostring(destGUID), amount, spellName, school or 1, spellId or 0, isPet and " [PET]" or ""))
    
    -- Get nameplate for this GUID
    local nameplate = self:GetNameplateByGUID(destGUID)
    if not nameplate and not isPersonal then 
        self:Debug("No nameplate found for damage GUID: " .. tostring(destGUID))
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
        local autoattack = spellName == AutoAttack or spellName == AutoShot or spellName == Shoot or 
                          spellName == "Auto Attack" or spellName == "Attack" -- Pet auto attacks often show as "Attack"
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
    text = self:ColorText(text, school, spellName, isPersonal, isPet)
    
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
    
    self:Debug(string.format("Displaying %s text on nameplate", isPet and "PET" or "PLAYER"))
    self:DisplayText(nameplate, text, size, alpha, animation, spellId, crit and not isPersonal, spellName, isPersonal, destGUID)
end

-- Display miss event
function SCT:MissEvent(destGUID, spellName, missType, spellId, isPet)
    local config = NotPlater.db.profile.sct
    
    if not config.general.enable then return end
    if isPet and not config.display.showPetDamage then return end
    
    local playerGUID = UnitGUID("player")
    local isPersonal = destGUID == playerGUID
    
    if isPersonal and not config.display.showPersonal then return end
    
    self:Debug(string_format("MissEvent: %s on %s from %s%s", missType, tostring(destGUID), spellName, isPet and " [PET]" or ""))
    
    -- Get nameplate for this GUID
    local nameplate = self:GetNameplateByGUID(destGUID)
    if not nameplate and not isPersonal then return end
    
    if isPersonal and not nameplate then
        nameplate = UIParent
    end
    
    local isTarget = UnitExists("target") and UnitGUID("target") == destGUID
    
    local animation = isPersonal and config.animations.personal.miss or config.animations.miss
    if animation == "disabled" then return end
    
    local text = MISS_EVENT_STRINGS[missType] or "Miss"
    local color = isPet and config.colors.petColor or (isPersonal and config.colors.personalColor or config.colors.defaultColor)
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

-- Display text with icon support
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
    
    -- Set icon if enabled and available
    if config.display.showIcon and fontString.icon then
        local texture = nil
        
        -- Try to get spell texture
        if spellId and spellId > 0 then
            local _, _, spellTexture = GetSpellInfo(spellId)
            texture = spellTexture
            self:Debug(string.format("Got icon for spellId %d: %s", spellId, tostring(texture)))
        end
        
        -- Fallback to spell name
        if not texture and spellName and spellName ~= "" and spellName ~= "Attack" then
            local _, _, spellTexture = GetSpellInfo(spellName)
            texture = spellTexture
            self:Debug(string.format("Got icon for spell name '%s': %s", spellName, tostring(texture)))
        end
        
        -- Special case for pet auto attacks which often show as "Attack"
        if not texture and spellName == "Attack" then
            texture = "Interface\\Icons\\Ability_GhoulFrenzy"  -- Generic claw icon for pet attacks
        end
        
        if texture then
            fontString.icon:SetTexture(texture)
            fontString.icon:SetSize(size * config.display.iconScale, size * config.display.iconScale)
            fontString.icon:SetPoint("RIGHT", fontString, "LEFT", -2, 0)
            fontString.icon:SetAlpha(alpha)
            fontString.icon:Show()
        else
            fontString.icon:Hide()
        end
    elseif fontString.icon then
        fontString.icon:Hide()
    end
    
    self:Animate(fontString, nameplate, 1.5, animation, guid)
end

-- Combat log event handler
function SCT:COMBAT_LOG_EVENT_UNFILTERED(timestamp, eventType, srcGUID, srcName, srcFlags, destGUID, destName, destFlags, ...)
    -- First check if SCT is enabled
    if not NotPlater.db.profile.sct.general.enable then
        return
    end
    
    local playerGUID = UnitGUID("player")
    local petGUID = self:GetPetGUID()
    local isPet = self:IsMyPet(srcFlags) or (petGUID and srcGUID == petGUID)
    
    -- Process damage from player OR player's pet
    if srcGUID == playerGUID or isPet then
        self:Debug(string.format("Processing %s event from %s%s to %s", 
            eventType, srcName or "unknown", isPet and " [PET]" or "", destName or "unknown"))
        
        if eventType == "SWING_DAMAGE" then
            local amount, overkill, _, _, _, _, critical = ...
            self:DamageEvent(destGUID, isPet and "Attack" or (AutoAttack or "Auto Attack"), 
                amount, overkill, 1, critical, 6603, false, isPet)
            
        elseif eventType == "RANGE_DAMAGE" then
            local spellId, spellName, school, amount, overkill, _, _, _, _, critical = ...
            self:Debug(string.format("RANGE_DAMAGE: spell=%s, id=%d, amount=%d", 
                spellName or "unknown", spellId or 0, amount or 0))
            self:DamageEvent(destGUID, spellName or "Ranged", amount, overkill, school, critical, spellId, false, isPet)
            
        elseif eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" then
            local spellId, spellName, school, amount, overkill, _, _, _, _, critical = ...
            self:Debug(string.format("SPELL_DAMAGE: spell=%s, id=%d, amount=%d", 
                spellName or "unknown", spellId or 0, amount or 0))
            self:DamageEvent(destGUID, spellName, amount, overkill, school, critical, spellId, false, isPet)
            
        elseif eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
            local spellId, spellName, school, amount, overheal, _, critical = ...
            self:DamageEvent(destGUID, spellName, amount, overheal, school, critical, spellId, true, isPet)
            
        elseif eventType == "SWING_MISSED" then
            local missType = ...
            self:MissEvent(destGUID, isPet and "Attack" or (AutoAttack or "Auto Attack"), 
                missType, 6603, isPet)
            
        elseif eventType == "RANGE_MISSED" then
            local spellId, spellName, school, missType = ...
            self:MissEvent(destGUID, spellName or "Ranged", missType, spellId, isPet)
            
        elseif eventType == "SPELL_MISSED" or eventType == "SPELL_PERIODIC_MISSED" then
            local spellId, spellName, school, missType = ...
            self:MissEvent(destGUID, spellName, missType, spellId, isPet)
        end
    end
    
    -- Process incoming damage to player
    if destGUID == playerGUID and NotPlater.db.profile.sct.display.showPersonal then
        if eventType == "SWING_DAMAGE" then
            local amount, overkill, _, _, _, _, critical = ...
            self:DamageEvent(destGUID, "Melee", amount, overkill, 1, critical, 6603, false, false)
            
        elseif string.find(eventType, "_DAMAGE") then
            local spellId, spellName, school, amount, overkill, _, _, _, _, critical
            if string.find(eventType, "SWING_") then
                amount, overkill = ...
                critical = select(7, ...)
                spellId = 6603
                spellName = "Melee"
                school = 1
            else
                spellId, spellName, school, amount, overkill = ...
                critical = select(9, ...)
            end
            
            if amount then
                self:DamageEvent(destGUID, spellName or "Unknown", amount, overkill or 0, school or 1, critical, spellId, false, false)
            end
            
        elseif string.find(eventType, "_HEAL") and NotPlater.db.profile.sct.display.showHeals then
            local spellId, spellName, school, amount, overheal, _, critical = ...
            if spellId and amount then
                self:DamageEvent(destGUID, spellName or "Heal", amount, overheal or 0, school or 2, critical, spellId, true, false)
            end
            
        elseif string.find(eventType, "_MISSED") then
            local spellId, spellName, school, missType = ...
            if missType then
                self:MissEvent(destGUID, spellName or "Attack", missType, spellId or 0, false)
            end
        end
    end
end

-- Test mode
function SCT:TestMode()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: SCT Test mode - Testing on current target or player")
    
    local testGUID = UnitGUID("target")
    local testLocation = "target"
    if not testGUID then
        testGUID = UnitGUID("player")
        testLocation = "player"
    end
    
    if not testGUID then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: No valid target for test")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Testing on " .. testLocation)
    
    local testEvents = {
        {amount = 1234, crit = false, school = 1, spell = "Sinister Strike", spellId = 1752},
        {amount = 5678, crit = true, school = 4, spell = "Fireball", spellId = 133},
        {amount = 999, crit = false, school = 8, spell = "Lightning Bolt", spellId = 403},
        {amount = 2500, crit = false, school = 16, spell = "Frost Bolt", spellId = 116},
        {amount = 1337, crit = false, school = 1, spell = "Auto Shot", spellId = 75},
        {amount = 888, crit = false, school = 1, spell = "Claw", spellId = 16827, isPet = true},  -- Pet Claw
        {amount = 456, crit = true, school = 1, spell = "Bite", spellId = 17253, isPet = true},  -- Pet Bite
        {missType = "DODGE", spell = "Heroic Strike", spellId = 78},
        {missType = "PARRY", spell = "Growl", spellId = 2649, isPet = true},  -- Pet taunt miss
    }
    
    for i, event in ipairs(testEvents) do
        C_Timer.After(i * 0.3, function()
            if event.missType then
                self:MissEvent(testGUID, event.spell, event.missType, event.spellId, event.isPet)
            else
                self:DamageEvent(testGUID, event.spell, event.amount, 0, event.school, event.crit, event.spellId, false, event.isPet)
            end
        end)
    end
end

-- Initialize
function SCT:Initialize()
    self:InitializeDefaults()
    
    -- Create our own frame for event handling
    local eventFrame = CreateFrame("Frame", "NotPlaterSCTEventFrame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Set up the event handler
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            SCT:COMBAT_LOG_EVENT_UNFILTERED(...)
        end
    end)
    
    self.eventFrame = eventFrame
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: SCT module initialized with pet damage support")
end

-- Initialize when ready
C_Timer.After(1, function()
    if NotPlater and NotPlater.SCT then
        NotPlater.SCT:Initialize()
    end
end)