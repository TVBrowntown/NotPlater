-- modules/core/frameManager.lua
-- Simplified and fixed frame management and lifecycle

if not NotPlater then return end

local FrameManager = {}
NotPlater.FrameManager = FrameManager

-- Frame registry
local managedFrames = {}
local framePool = {}
local numChildren = -1

-- Initialize the frame manager
function FrameManager:Initialize()
    -- Set up the main update frame
    self:SetupUpdateFrame()
end

-- Set up the main update frame
function FrameManager:SetupUpdateFrame()
    if not NotPlater.frame then
        NotPlater.frame = CreateFrame("Frame")
    end
    
    local updateThrottle = 0
    local cleanupTimer = 0
    local colorUpdateTimer = 0
    local UPDATE_INTERVAL = 0.1
    local CLEANUP_INTERVAL = 30
    local COLOR_UPDATE_INTERVAL = 2
    
    NotPlater.frame:SetScript("OnUpdate", function(self, elapsed)
        updateThrottle = updateThrottle + elapsed
        if updateThrottle >= UPDATE_INTERVAL then
            -- Check for new nameplates
            if WorldFrame:GetNumChildren() ~= numChildren then
                numChildren = WorldFrame:GetNumChildren()
                FrameManager:ScanForNameplates(WorldFrame:GetChildren())
            end
            updateThrottle = 0
        end
        
        -- Periodic cleanup
        cleanupTimer = cleanupTimer + elapsed
        if cleanupTimer >= CLEANUP_INTERVAL then
            FrameManager:CleanupDeadFrames()
            cleanupTimer = 0
        end
        
        -- Periodic color updates for all frames
        colorUpdateTimer = colorUpdateTimer + elapsed
        if colorUpdateTimer >= COLOR_UPDATE_INTERVAL then
            FrameManager:UpdateAllFrameColors()
            colorUpdateTimer = 0
        end
    end)
end

-- Scan for new nameplate frames
function FrameManager:ScanForNameplates(...)
    local numArgs = select("#", ...)
    for i = 1, numArgs do
        local frame = select(i, ...)
        if not managedFrames[frame] and not frame:GetName() then
            local region = frame:GetRegions()
            if region and region:GetObjectType() == "Texture" and 
               region:GetTexture() == "Interface\\TargetingFrame\\UI-TargetingFrame-Flash" then
                self:RegisterNameplate(frame)
            end
        end
    end
end

-- Register a nameplate frame
function FrameManager:RegisterNameplate(frame)
    managedFrames[frame] = true
    
    -- Initialize frame components
    if NotPlater.PrepareFrame then
        NotPlater:PrepareFrame(frame)
    end
    
    -- Set up frame-specific update handler
    self:SetupFrameUpdates(frame)
end

-- Set up per-frame update handlers
function FrameManager:SetupFrameUpdates(frame)
    -- OnShow handler
    if not frame.npOnShowHooked then
        NotPlater:HookScript(frame, "OnShow", function(self)
            FrameManager:OnNameplateShow(self)
        end)
        frame.npOnShowHooked = true
    end
    
    -- OnHide handler
    if not frame.npOnHideHooked then
        NotPlater:HookScript(frame, "OnHide", function(self)
            FrameManager:OnNameplateHide(self)
        end)
        frame.npOnHideHooked = true
    end
    
    -- OnUpdate handler for per-frame updates
    if not frame.npOnUpdateHooked then
        local frameUpdateElapsed = 0
        local initialColorCheck = true
        NotPlater:HookScript(frame, "OnUpdate", function(self, elapsed)
            frameUpdateElapsed = frameUpdateElapsed + elapsed
            
            -- Quick initial color check
            if initialColorCheck and frameUpdateElapsed >= 0.05 then
                FrameManager:UpdateFrameColor(self)
                initialColorCheck = false
            end
            
            if frameUpdateElapsed >= 0.1 then
                FrameManager:OnNameplateUpdate(self)
                frameUpdateElapsed = 0
            end
        end)
        frame.npOnUpdateHooked = true
    end
end

-- Handle nameplate show event
function FrameManager:OnNameplateShow(frame)
    -- Don't clear color cache completely, just mark for update
    frame.needsColorUpdate = true
    frame.initialShow = true
    
    -- Immediate color application with better detection
    self:ApplyInitialColor(frame)
    
    -- Show cast bar if needed
    if NotPlater.CastBarOnShow then
        NotPlater:CastBarOnShow(frame)
    end
    
    -- Update stacking
    if NotPlater.StackingCheck then
        NotPlater:StackingCheck(frame)
    end
    
    -- Check if target
    if NotPlater.TargetCheck then
        NotPlater:TargetCheck(frame)
    end
    
    frame.targetChanged = true
end

-- Apply initial color when nameplate shows - FIXED
function FrameManager:ApplyInitialColor(frame)
    if not frame or not NotPlater.ColorManager then return end
    
    -- Get nameplate info
    local nameText, levelText = select(7, frame:GetRegions())
    local playerName = nameText and nameText:GetText()
    local level = levelText and levelText:GetText()
    
    if not playerName then return end
    
    -- Try to get color from any source
    local color, colorType = NotPlater.ColorManager:GetNameplateColor(frame, playerName, nil)
    
    if color and colorType ~= "fallback" then
        NotPlater.ColorManager:ApplyNameplateColor(frame, color, colorType)
    else
        -- Better fallback detection using level text color
        local defaultColor = nil
        
        if levelText then
            local r, g, b = levelText:GetTextColor()
            
            -- Level text color indicates faction:
            -- Red (r > 0.9, g < 0.2, b < 0.2) = Hostile
            -- Yellow (r > 0.9, g > 0.9, b < 0.2) = Neutral  
            -- Green/White = Friendly
            
            if r and g and b then
                local reactionColors = NotPlater.db.profile.healthBar.coloring.reactionColors
                
                if r > 0.9 and g < 0.2 and b < 0.2 then
                    -- Red level = hostile
                    defaultColor = reactionColors.hostile
                    frame.detectedReaction = "hostile"
                elseif r > 0.9 and g > 0.9 and b < 0.2 then
                    -- Yellow level = neutral
                    defaultColor = reactionColors.neutral
                    frame.detectedReaction = "neutral"
                else
                    -- Green/White level = friendly
                    defaultColor = reactionColors.friendly
                    frame.detectedReaction = "friendly"
                end
            end
        end
        
        -- If we still don't have a color, use neutral as safer default
        if not defaultColor then
            local reactionColors = NotPlater.db.profile.healthBar.coloring.reactionColors
            defaultColor = reactionColors.neutral
            frame.detectedReaction = "neutral"
        end
        
        if frame.healthBar and defaultColor then
            frame.healthBar:SetStatusBarColor(defaultColor.r, defaultColor.g, defaultColor.b, defaultColor.a or 1)
            frame.currentColor = defaultColor
            frame.currentColorType = "initial_" .. (frame.detectedReaction or "unknown")
        end
    end
    
    -- Mark that we need a better color update soon
    frame.needsColorUpdate = true
end

-- Handle nameplate hide event
function FrameManager:OnNameplateHide(frame)
    -- Don't clear color cache, just unit data
    frame.unit = nil
    frame.unitGUID = nil
    frame.wasTarget = nil
    frame.needsColorUpdate = nil
    frame.initialShow = nil
    
    -- Hide cast bar
    if frame.castBar then
        frame.castBar:Hide()
        frame.castBar.casting = nil
        frame.castBar.channeling = nil
    end
    
    -- Hide threat icon
    if frame.threatIcon then
        frame.threatIcon:Hide()
    end
end

-- Handle nameplate update
function FrameManager:OnNameplateUpdate(frame)
    if not frame:IsShown() then return end
    
    -- Check if target changed
    local isTarget = NotPlater:IsTarget(frame)
    if frame.wasTarget ~= isTarget then
        frame.targetChanged = true
        frame.wasTarget = isTarget
        frame.needsColorUpdate = true
    end
    
    -- Handle target changes
    if frame.targetChanged then
        if NotPlater.TargetCheck then
            NotPlater:TargetCheck(frame)
        end
        frame.targetChanged = nil
    end
    
    -- Update threat icon if enabled
    if NotPlater.db.profile.threatIcon and NotPlater.db.profile.threatIcon.general.enable then
        if NotPlater.UpdateThreatIcon then
            self:UpdateFrameUnitInfo(frame)
            NotPlater:UpdateThreatIcon(frame)
        end
    end
    
    -- Update colors if needed or on initial show
    if frame.needsColorUpdate or frame.initialShow then
        self:UpdateFrameColor(frame)
        frame.needsColorUpdate = nil
        frame.initialShow = nil
    end
    
    -- Update target text
    if NotPlater.SetTargetTargetText then
        NotPlater:SetTargetTargetText(frame)
    end
    
    -- Handle alpha changes for non-target nameplates
    if isTarget then
        frame:SetAlpha(1)
    elseif NotPlater.db.profile.target.general.nonTargetAlpha.enable then
        frame:SetAlpha(NotPlater.db.profile.target.general.nonTargetAlpha.opacity)
    end
end

-- Update frame unit info for threat/other systems
function FrameManager:UpdateFrameUnitInfo(frame)
    if not frame then return end
    
    local nameText, levelText = select(7, frame:GetRegions())
    if not nameText or not levelText then return end
    
    local name = nameText:GetText()
    local level = levelText:GetText()
    
    if name and level then
        -- Check common unit IDs
        if UnitExists("target") and name == UnitName("target") and 
           level == tostring(UnitLevel("target")) then
            frame.unit = "target"
            frame.unitGUID = UnitGUID("target")
        elseif UnitExists("mouseover") and name == UnitName("mouseover") and 
               level == tostring(UnitLevel("mouseover")) then
            frame.unit = "mouseover"
            frame.unitGUID = UnitGUID("mouseover")
        elseif UnitExists("pet") and name == UnitName("pet") then
            frame.unit = "pet"
            frame.unitGUID = UnitGUID("pet")
        end
    end
end

-- Update single frame color - IMPROVED
function FrameManager:UpdateFrameColor(frame)
    if not frame or not NotPlater.ColorManager then return end
    
    -- Get nameplate info
    local nameText = select(7, frame:GetRegions())
    local playerName = nameText and nameText:GetText()
    
    if playerName then
        -- Update unit info
        self:UpdateFrameUnitInfo(frame)
        
        -- Get color with comprehensive detection
        local color, colorType = NotPlater.ColorManager:GetNameplateColor(frame, playerName, frame.unit)
        
        -- If we get a real color (not fallback), apply it
        if color and colorType ~= "fallback" then
            NotPlater.ColorManager:ApplyNameplateColor(frame, color, colorType)
            frame.currentColorType = colorType
        elseif frame.detectedReaction and not frame.currentColor then
            -- Use our detected reaction if we don't have a better color yet
            local reactionColors = NotPlater.db.profile.healthBar.coloring.reactionColors
            local reactionColor = reactionColors[frame.detectedReaction]
            if reactionColor then
                NotPlater.ColorManager:ApplyNameplateColor(frame, reactionColor, "detected_" .. frame.detectedReaction)
            end
        end
        
        -- Continue trying to get better color detection
        if not frame.unit or (frame.currentColorType and string.find(frame.currentColorType, "fallback")) then
            frame.needsColorUpdate = true
        end
    end
end

-- Update all frame colors periodically
function FrameManager:UpdateAllFrameColors()
    if not NotPlater.ColorManager then return end
    
    for frame in pairs(managedFrames) do
        if frame:IsShown() then
            -- Always update if no color or fallback color
            local needsUpdate = false
            
            -- Always update target
            if NotPlater:IsTarget(frame) then
                needsUpdate = true
            end
            
            -- Update if no color assigned
            if not frame.currentColor or not frame.currentColorType then
                needsUpdate = true
            end
            
            -- Update if we have a fallback or initial color
            if frame.currentColorType and (string.find(frame.currentColorType, "fallback") or 
                                           string.find(frame.currentColorType, "initial")) then
                needsUpdate = true
            end
            
            -- Update if mouseover (for immediate feedback)
            local nameText = select(7, frame:GetRegions())
            local playerName = nameText and nameText:GetText()
            if playerName and UnitExists("mouseover") and playerName == UnitName("mouseover") then
                needsUpdate = true
            end
            
            if needsUpdate then
                self:UpdateFrameColor(frame)
            end
        end
    end
end

-- Clean up dead frames
function FrameManager:CleanupDeadFrames()
    local deadFrames = {}
    
    for frame in pairs(managedFrames) do
        if not frame:GetParent() or not frame:IsVisible() then
            table.insert(deadFrames, frame)
        end
    end
    
    for _, frame in ipairs(deadFrames) do
        managedFrames[frame] = nil
        
        -- Clear frame data
        if frame.healthBar then
            frame.healthBar.lastValue = nil
            frame.healthBar.lastMaxValue = nil
            frame.healthBar.lastTextUpdate = nil
        end
        
        frame.detectedReaction = nil
        frame.currentColorType = nil
    end
    
    -- Return dead frames to pool for reuse
    for _, frame in ipairs(deadFrames) do
        table.insert(framePool, frame)
    end
end

-- Get all managed frames
function FrameManager:GetManagedFrames()
    return managedFrames
end

-- Force update all frames
function FrameManager:UpdateAllFrames()
    for frame in pairs(managedFrames) do
        if frame:IsShown() then
            -- Mark for color update
            frame.needsColorUpdate = true
            
            -- Update immediately
            self:UpdateFrameColor(frame)
            
            -- Update other components
            self:OnNameplateUpdate(frame)
        end
    end
end

-- Force color refresh for all frames
function FrameManager:RefreshAllColors()
    for frame in pairs(managedFrames) do
        if frame:IsShown() then
            -- Don't completely clear, just mark for update
            frame.needsColorUpdate = true
            
            -- Force immediate update
            self:UpdateFrameColor(frame)
        end
    end
end