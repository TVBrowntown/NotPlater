-- modules/sct.lua
-- Scrolling Combat Text module for NotPlater
-- FIXED VERSION: Prevents combat text from appearing on wrong nameplates

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

-- GUID validation cache with timestamps
local nameplateGUIDs = {} -- [frame] = {guid = guid, timestamp = time, verified = bool}
local GUID_CACHE_TIMEOUT = 5 -- seconds before we re-verify GUID
local ANIMATION_GUID_CHECK_INTERVAL = 0.5 -- Check GUID validity during animation every 0.5s

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

-- Direction tracking
local arcDirection = 1

-- Spell info
local AutoAttack = GetSpellInfo(6603) or "Auto Attack"
local AutoShot = GetSpellInfo(75) or "Auto Shot"
local Shoot = GetSpellInfo(5019) or "Shoot"

-- Color definitions and other constants remain the same...
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
                showPetDamage = true,
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
                petColor = "CC8400",
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

-- Check if source is player's pet
function SCT:IsMyPet(srcFlags)
    return CombatLog_Object_IsA(srcFlags, COMBATLOG_FILTER_MY_PET)
end

-- Get pet's GUID
function SCT:GetPetGUID()
    if UnitExists("pet") then
        return UnitGUID("pet")
    end
    return nil
end

-- ENHANCED: Strict GUID verification for nameplates - ZERO tolerance for mismatches
function SCT:VerifyNameplateGUID(frame, targetGUID)
    if not frame or not targetGUID then
        return false
    end
    
    -- For player, simple check
    if targetGUID == UnitGUID("player") then
        return frame == UIParent
    end
    
    local currentTime = GetTime()
    local cacheEntry = nameplateGUIDs[frame]
    
    -- If we have a recent cache entry that matches, use it
    if cacheEntry and 
       cacheEntry.guid == targetGUID and 
       cacheEntry.verified and
       (currentTime - cacheEntry.timestamp) < GUID_CACHE_TIMEOUT then
        return true
    end
    
    -- Get nameplate display info
    local nameText, levelText = select(7, frame:GetRegions())
    if not nameText or not levelText then
        nameplateGUIDs[frame] = nil
        self:Debug("VerifyNameplateGUID: No nameText or levelText on frame")
        return false
    end
    
    local frameName = nameText:GetText()
    local frameLevel = levelText:GetText()
    if not frameName or not frameLevel then
        nameplateGUIDs[frame] = nil
        self:Debug("VerifyNameplateGUID: Empty name or level on nameplate")
        return false
    end
    
    -- CRITICAL: Find a unit that has EXACTLY this GUID
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
    
    -- STRICT CHECK: Must find a unit with EXACTLY the target GUID
    local foundMatchingUnit = false
    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) and UnitGUID(unit) == targetGUID then
            local unitName = UnitName(unit)
            local unitLevel = tostring(UnitLevel(unit))
            
            -- TRIPLE CHECK: GUID matches AND name matches AND level matches
            if unitName == frameName and unitLevel == frameLevel then
                -- Perfect match - cache it
                nameplateGUIDs[frame] = {
                    guid = targetGUID,
                    timestamp = currentTime,
                    verified = true
                }
                foundMatchingUnit = true
                self:Debug(string.format("VERIFIED: Frame matches GUID %s via unit %s (name:%s level:%s)", 
                    targetGUID:sub(-8), unit, unitName, unitLevel))
                return true
            else
                -- GUID matches but name/level doesn't - this is suspicious
                self:Debug(string.format("WARNING: Found unit %s with GUID %s but name/level mismatch. Unit: %s/%s, Frame: %s/%s", 
                    unit, targetGUID:sub(-8), unitName or "nil", unitLevel or "nil", frameName, frameLevel))
            end
        end
    end
    
    -- If we reach here, no unit with the target GUID was found or name/level didn't match
    nameplateGUIDs[frame] = nil
    if not foundMatchingUnit then
        self:Debug(string.format("STRICT FAIL: No unit found with GUID %s (nameplate shows %s level %s)", 
            targetGUID:sub(-8), frameName, frameLevel))
    end
    
    return false
end

-- ENHANCED: Get nameplate by GUID with STRICT verification - NO FALLBACKS
function SCT:GetNameplateByGUID(guid)
    if not guid then
        self:Debug("GetNameplateByGUID called with nil GUID")
        return nil
    end
    
    local playerGUID = UnitGUID("player")
    
    -- Check if it's the player
    if guid == playerGUID then
        return UIParent
    end
    
    -- First try cached entries - but still verify they're current
    for frame, cacheEntry in pairs(nameplateGUIDs) do
        if cacheEntry.guid == guid and 
           cacheEntry.verified and 
           frame:IsShown() and
           (GetTime() - cacheEntry.timestamp) < GUID_CACHE_TIMEOUT then
            -- Double-check the cached entry is still valid
            if self:VerifyNameplateGUID(frame, guid) then
                self:Debug(string.format("Using cached nameplate for GUID %s", guid:sub(-8)))
                return frame
            else
                -- Cache entry is stale, remove it
                nameplateGUIDs[frame] = nil
                self:Debug(string.format("Cached nameplate for GUID %s became invalid", guid:sub(-8)))
            end
        end
    end
    
    -- Search through all visible nameplates - STRICT GUID matching only
    if NotPlater.frames then
        for frame in pairs(NotPlater.frames) do
            if frame:IsShown() then
                -- CRITICAL: Only return if this exact GUID is verified
                if self:VerifyNameplateGUID(frame, guid) then
                    self:Debug(string.format("Found verified nameplate for GUID %s", guid:sub(-8)))
                    return frame
                end
            end
        end
    end
    
    -- ABSOLUTELY NO FALLBACKS - if we can't find the exact GUID, return nil
    self:Debug(string.format("STRICT CHECK: No nameplate found for GUID %s - damage will not display", guid:sub(-8)))
    return nil
end

-- ENHANCED: Validate animation anchor with position capture (no hidden frames)
function SCT:ValidateAnimationAnchor(fontString)
    if not fontString.anchorFrame or not fontString.guid then
        return false
    end
    
    -- For player, always valid
    if fontString.guid == UnitGUID("player") then
        return fontString.anchorFrame == UIParent
    end
    
    -- If we've already captured absolute position, it's always valid
    if fontString.absolutePosition then
        return true
    end
    
    -- Check if nameplate is no longer shown (death/out of range)
    if not fontString.anchorFrame:IsShown() then
        -- Capture absolute position and switch to absolute positioning
        self:CaptureAbsolutePosition(fontString)
        return true
    end
    
    -- Check if we need to re-verify (throttled to avoid excessive checks)
    local currentTime = GetTime()
    if not fontString.lastGuidCheck then
        fontString.lastGuidCheck = 0
    end
    
    if (currentTime - fontString.lastGuidCheck) >= ANIMATION_GUID_CHECK_INTERVAL then
        fontString.lastGuidCheck = currentTime
        local isValid = self:VerifyNameplateGUID(fontString.anchorFrame, fontString.guid)
        fontString.guidValid = isValid
        
        if not isValid then
            -- Nameplate was recycled for different NPC - this is bad, terminate animation
            self:Debug(string.format("Animation anchor became invalid for GUID %s (nameplate recycled)", fontString.guid:sub(-8)))
            return false
        end
        
        return true
    end
    
    -- Return cached result if we checked recently
    return fontString.guidValid ~= false -- Default to true if not set
end

-- Capture absolute screen position when nameplate disappears (no hidden frames needed)
function SCT:CaptureAbsolutePosition(fontString)
    if fontString.absolutePosition then
        return -- Already captured
    end
    
    -- Get current screen position of the animation text
    local currentX, currentY = fontString:GetCenter()
    if not currentX or not currentY then
        -- Fallback: use the original anchor frame position if animation hasn't started moving yet
        if fontString.anchorFrame and fontString.anchorFrame:IsShown() then
            local anchorX, anchorY = fontString.anchorFrame:GetCenter()
            if anchorX and anchorY then
                -- Add the configured base offsets to get the text starting position
                local config = NotPlater.db.profile.sct
                local baseXOffset = fontString.isPersonal and config.position.personalXOffset or config.position.xOffset
                local baseYOffset = fontString.isPersonal and config.position.personalYOffset or config.position.yOffset
                currentX = anchorX + baseXOffset
                currentY = anchorY + baseYOffset
            end
        end
        
        if not currentX or not currentY then
            -- Last resort: center of screen
            currentX, currentY = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
        end
    end
    
    -- Store absolute position (no frames needed!)
    fontString.absolutePosition = {
        x = currentX,
        y = currentY
    }
    
    self:Debug(string.format("Captured absolute position for GUID %s at (%.0f, %.0f)", 
        fontString.guid:sub(-8), currentX, currentY))
end

-- Font string management (unchanged)
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

-- ENHANCED: Clean up with no hidden frames needed
function SCT:RecycleFontString(fontString)
    fontString:SetAlpha(0)
    fontString:Hide()
    
    animating[fontString] = nil
    
    -- Clear all properties including GUID validation and absolute position
    fontString.distance = nil
    fontString.arcTop = nil
    fontString.arcBottom = nil
    fontString.arcXDist = nil
    fontString.animation = nil
    fontString.animatingDuration = nil
    fontString.animatingStartTime = nil
    fontString.anchorFrame = nil
    fontString.guid = nil
    fontString.guidValid = nil
    fontString.lastGuidCheck = nil
    fontString.startHeight = nil
    fontString.pow = nil
    fontString.rainfallX = nil
    fontString.rainfallStartY = nil
    fontString.isPersonal = nil
    fontString.absolutePosition = nil -- Just clear the coordinates, no frames to clean up
    
    if fontString.icon then
        fontString.icon:ClearAllPoints()
        fontString.icon:SetAlpha(0)
        fontString.icon:Hide()
    end
    
    fontString:ClearAllPoints()
    
    table_insert(fontStringCache, fontString)
end

-- Animation paths (unchanged)
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

-- ENHANCED: Animation update with absolute positioning (no hidden frames)
local function AnimationOnUpdate()
    if not next(animating) then
        SCT.animationFrame:SetScript("OnUpdate", nil)
        return
    end
    
    local toRecycle = {}
    
    for fontString, _ in pairs(animating) do
        local elapsed = GetTime() - fontString.animatingStartTime
        
        -- Check if animation should end
        if elapsed > fontString.animatingDuration then
            table_insert(toRecycle, fontString)
        else
            -- CRITICAL: Validate anchor frame before positioning
            if not SCT:ValidateAnimationAnchor(fontString) then
                -- Anchor is invalid (nameplate recycled for different NPC) - stop animation
                SCT:Debug(string.format("Stopping animation due to invalid anchor (GUID: %s)", 
                    fontString.guid and fontString.guid:sub(-8) or "unknown"))
                table_insert(toRecycle, fontString)
            else
                -- Continue animation
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
                
                -- Position the text using absolute positioning or relative to nameplate
                if fontString.absolutePosition then
                    -- Use captured absolute position (death/out of range case)
                    local finalX = fontString.absolutePosition.x + xOffset
                    local finalY = fontString.absolutePosition.y + yOffset
                    fontString:SetPoint("CENTER", UIParent, "BOTTOMLEFT", finalX, finalY)
                else
                    -- Use relative positioning to live nameplate
                    local config = NotPlater.db.profile.sct
                    local baseXOffset = fontString.isPersonal and config.position.personalXOffset or config.position.xOffset
                    local baseYOffset = fontString.isPersonal and config.position.personalYOffset or config.position.yOffset
                    fontString:SetPoint("CENTER", fontString.anchorFrame, "CENTER", 
                        baseXOffset + xOffset, baseYOffset + yOffset)
                end
            end
        end
    end
    
    -- Recycle completed/invalid animations
    for _, fontString in ipairs(toRecycle) do
        SCT:RecycleFontString(fontString)
    end
end

-- ENHANCED: Start animation with GUID tracking
function SCT:Animate(fontString, anchorFrame, duration, animation, guid)
    local config = NotPlater.db.profile.sct
    
    fontString.animation = animation
    fontString.animatingDuration = duration / config.animations.speed
    fontString.animatingStartTime = GetTime()
    fontString.anchorFrame = anchorFrame
    fontString.guid = guid
    fontString.guidValid = true -- Start as valid, will be checked during animation
    fontString.lastGuidCheck = GetTime()
    
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

-- Format number and color text functions remain the same...
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

function SCT:ColorText(text, school, spellName, isPersonal, isPet)
    local config = NotPlater.db.profile.sct
    
    if isPet then
        return string_format("\124cff%s%s\124r", config.colors.petColor or "CC8400", text)
    elseif config.colors.damageColor and DAMAGE_TYPE_COLORS[school] then
        return string_format("\124cff%s%s\124r", DAMAGE_TYPE_COLORS[school], text)
    else
        local color = isPersonal and config.colors.personalColor or config.colors.defaultColor
        return string_format("\124cff%s%s\124r", color, text)
    end
end

-- ENHANCED: Damage event with ABSOLUTE GUID verification - no exceptions
function SCT:DamageEvent(destGUID, spellName, amount, overkill, school, crit, spellId, isHeal, isPet)
    local config = NotPlater.db.profile.sct
    
    if not config.general.enable then return end
    if isHeal and not config.display.showHeals then return end
    if isPet and not config.display.showPetDamage then return end
    
    if not destGUID then
        self:Debug("DamageEvent: No destination GUID provided")
        return
    end
    
    local playerGUID = UnitGUID("player")
    local isPersonal = destGUID == playerGUID
    
    if isPersonal and not config.display.showPersonal then return end
    
    self:Debug(string.format("DamageEvent: GUID %s took %d from %s (school:%d, spellId:%d)%s", 
        destGUID:sub(-8), amount, spellName, school or 1, spellId or 0, isPet and " [PET]" or ""))
    
    local nameplate = nil
    
    if isPersonal then
        -- Personal damage always goes to UIParent
        nameplate = UIParent
        self:Debug("Using UIParent for personal damage")
    else
        -- CRITICAL: Get nameplate with ABSOLUTE GUID verification
        nameplate = self:GetNameplateByGUID(destGUID)
        
        if not nameplate then
            -- NO NAMEPLATE FOUND - absolutely do not show damage anywhere else
            self:Debug(string.format("STRICT BLOCK: No verified nameplate found for GUID %s - damage NOT displayed", destGUID:sub(-8)))
            return
        end
        
        -- PARANOID DOUBLE-CHECK: Verify the returned nameplate still matches
        if not self:VerifyNameplateGUID(nameplate, destGUID) then
            self:Debug(string.format("STRICT BLOCK: Double-check verification failed for GUID %s - damage NOT displayed", destGUID:sub(-8)))
            return
        end
        
        self:Debug(string.format("VERIFIED: Using nameplate for GUID %s", destGUID:sub(-8)))
    end
    
    -- At this point, we have a verified nameplate or it's personal damage
    local isTarget = UnitExists("target") and UnitGUID("target") == destGUID
    
    -- Determine animation
    local animation
    if isPersonal then
        animation = crit and config.animations.personal.crit or config.animations.personal.normal
    else
        local autoattack = spellName == AutoAttack or spellName == AutoShot or spellName == Shoot or 
                          spellName == "Auto Attack" or spellName == "Attack"
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
    
    self:Debug(string.format("DISPLAYING: %s text on VERIFIED nameplate for GUID %s", 
        isPet and "PET" or "PLAYER", destGUID:sub(-8)))
    self:DisplayText(nameplate, text, size, alpha, animation, spellId, crit and not isPersonal, spellName, isPersonal, destGUID)
end

-- ENHANCED: Miss event with ABSOLUTE GUID verification - no exceptions
function SCT:MissEvent(destGUID, spellName, missType, spellId, isPet)
    local config = NotPlater.db.profile.sct
    
    if not config.general.enable then return end
    if isPet and not config.display.showPetDamage then return end
    
    if not destGUID then
        self:Debug("MissEvent: No destination GUID provided")
        return
    end
    
    local playerGUID = UnitGUID("player")
    local isPersonal = destGUID == playerGUID
    
    if isPersonal and not config.display.showPersonal then return end
    
    self:Debug(string.format("MissEvent: %s on GUID %s from %s%s", 
        missType, destGUID:sub(-8), spellName, isPet and " [PET]" or ""))
    
    local nameplate = nil
    
    if isPersonal then
        -- Personal miss always goes to UIParent
        nameplate = UIParent
        self:Debug("Using UIParent for personal miss")
    else
        -- CRITICAL: Get nameplate with ABSOLUTE GUID verification
        nameplate = self:GetNameplateByGUID(destGUID)
        
        if not nameplate then
            -- NO NAMEPLATE FOUND - absolutely do not show miss anywhere else
            self:Debug(string.format("STRICT BLOCK: No verified nameplate found for GUID %s - miss NOT displayed", destGUID:sub(-8)))
            return
        end
        
        -- PARANOID DOUBLE-CHECK: Verify the returned nameplate still matches
        if not self:VerifyNameplateGUID(nameplate, destGUID) then
            self:Debug(string.format("STRICT BLOCK: Double-check verification failed for GUID %s - miss NOT displayed", destGUID:sub(-8)))
            return
        end
        
        self:Debug(string.format("VERIFIED: Using nameplate for miss on GUID %s", destGUID:sub(-8)))
    end
    
    -- At this point, we have a verified nameplate or it's personal miss
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
    
    self:Debug(string.format("DISPLAYING: Miss text on VERIFIED nameplate for GUID %s", destGUID:sub(-8)))
    self:DisplayText(nameplate, text, size, alpha, animation, spellId, true, spellName, isPersonal, destGUID)
end

-- Display text with icon support (unchanged except for GUID parameter)
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
        end
        
        -- Fallback to spell name
        if not texture and spellName and spellName ~= "" and spellName ~= "Attack" then
            local _, _, spellTexture = GetSpellInfo(spellName)
            texture = spellTexture
        end
        
        -- Special case for pet auto attacks
        if not texture and spellName == "Attack" then
            texture = "Interface\\Icons\\Ability_GhoulFrenzy"
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
    
    -- ENHANCED: Pass GUID to animation system for validation
    self:Animate(fontString, nameplate, 1.5, animation, guid)
end

-- Combat log event handler (unchanged)
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
        self:Debug(string.format("Processing %s event from %s%s to GUID %s", 
            eventType, srcName or "unknown", isPet and " [PET]" or "", destGUID:sub(-8)))
        
        if eventType == "SWING_DAMAGE" then
            local amount, overkill, _, _, _, _, critical = ...
            self:DamageEvent(destGUID, isPet and "Attack" or (AutoAttack or "Auto Attack"), 
                amount, overkill, 1, critical, 6603, false, isPet)
            
        elseif eventType == "RANGE_DAMAGE" then
            local spellId, spellName, school, amount, overkill, _, _, _, _, critical = ...
            self:DamageEvent(destGUID, spellName or "Ranged", amount, overkill, school, critical, spellId, false, isPet)
            
        elseif eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" then
            local spellId, spellName, school, amount, overkill, _, _, _, _, critical = ...
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

-- ENHANCED: Cleanup function for GUID cache
function SCT:CleanupGUIDCache()
    local currentTime = GetTime()
    
    -- Clean up stale GUID cache entries
    for frame, cacheEntry in pairs(nameplateGUIDs) do
        if not frame:IsShown() or (currentTime - cacheEntry.timestamp) > GUID_CACHE_TIMEOUT * 2 then
            nameplateGUIDs[frame] = nil
        end
    end
end

-- Test mode with ABSOLUTE GUID verification and position capture
function SCT:TestMode()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: SCT Test mode - STRICT GUID verification enabled")
    
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
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Testing on " .. testLocation .. " (GUID: " .. testGUID:sub(-8) .. ")")
    DEFAULT_CHAT_FRAME:AddMessage("|cffeda55f→|r Combat text will ONLY appear on nameplates with matching GUID")
    DEFAULT_CHAT_FRAME:AddMessage("|cffeda55f→|r No fallbacks - if no correct nameplate exists, damage won't show")
    DEFAULT_CHAT_FRAME:AddMessage("|cffeda55f→|r Death animations continue floating using captured position (no hidden frames)")
    
    local testEvents = {
        {amount = 1234, crit = false, school = 1, spell = "Sinister Strike", spellId = 1752},
        {amount = 5678, crit = true, school = 4, spell = "Fireball", spellId = 133},
        {amount = 999, crit = false, school = 8, spell = "Lightning Bolt", spellId = 403},
        {amount = 2500, crit = false, school = 16, spell = "Frost Bolt", spellId = 116},
        {amount = 888, crit = false, school = 1, spell = "Claw", spellId = 16827, isPet = true},
        {missType = "DODGE", spell = "Heroic Strike", spellId = 78},
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

-- Initialize with cleanup timer
function SCT:Initialize()
    self:InitializeDefaults()
    
    -- Create event frame
    local eventFrame = CreateFrame("Frame", "NotPlaterSCTEventFrame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            SCT:COMBAT_LOG_EVENT_UNFILTERED(...)
        end
    end)
    
    self.eventFrame = eventFrame
    
    -- Create cleanup timer for GUID cache
    local cleanupFrame = CreateFrame("Frame")
    cleanupFrame.elapsed = 0
    cleanupFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 10 then -- Clean every 10 seconds
            self.elapsed = 0
            SCT:CleanupGUIDCache()
        end
    end)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: SCT module initialized with ABSOLUTE GUID verification and position capture")
end

-- Initialize when ready
C_Timer.After(1, function()
    if NotPlater and NotPlater.SCT then
        NotPlater.SCT:Initialize()
    end
end)