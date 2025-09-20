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
        NotPlater:HookScript(frame, "OnUpdate", function(self, elapsed)
            frameUpdateElapsed = frameUpdateElapsed + elapsed
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
    -- Clear all cached data
    if NotPlater.ColorManager then
        NotPlater.ColorManager:ClearFrameColorCache(frame)
    end
    
    -- Immediate color application
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
    frame.needsColorUpdate = true
end

-- Apply initial color when nameplate shows
function FrameManager:ApplyInitialColor(frame)
    if not frame or not NotPlater.ColorManager then return end
    
    -- Get nameplate info
    local nameText = select(7, frame:GetRegions())
    local playerName = nameText and nameText:GetText()
    
    if playerName then
        -- Try to get color from any source
        local color, colorType = NotPlater.ColorManager:GetNameplateColor(frame, playerName, nil)
        if color then
            NotPlater.ColorManager:ApplyNameplateColor(frame, color, colorType)
        else
            -- Apply default reaction color immediately
            local reactionColors = NotPlater.db.profile.healthBar.coloring.reactionColors
            local defaultColor = reactionColors.hostile -- Default to hostile red
            
            if frame.healthBar then
                frame.healthBar:SetStatusBarColor(defaultColor.r, defaultColor.g, defaultColor.b, defaultColor.a or 1)
            end
        end
    end
end

-- Handle nameplate hide event
function FrameManager:OnNameplateHide(frame)
    -- Clear all cached data
    if NotPlater.ColorManager then
        NotPlater.ColorManager:ClearFrameColorCache(frame)
    end
    
    -- Clear unit data
    frame.unit = nil
    frame.unitGUID = nil
    frame.wasTarget = nil
    frame.needsColorUpdate = nil
    
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
    
    -- Update colors if needed
    if frame.needsColorUpdate then
        self:UpdateFrameColor(frame)
        frame.needsColorUpdate = nil
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

-- Update single frame color
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
        
        if color then
            -- Apply the color
            NotPlater.ColorManager:ApplyNameplateColor(frame, color, colorType)
        end
    end
end

-- Update all frame colors periodically
function FrameManager:UpdateAllFrameColors()
    if not NotPlater.ColorManager then return end
    
    for frame in pairs(managedFrames) do
        if frame:IsShown() then
            -- Only update if frame doesn't have a recent color or is target
            local needsUpdate = false
            
            -- Always update target
            if NotPlater:IsTarget(frame) then
                needsUpdate = true
            end
            
            -- Update if no color assigned
            if not frame.currentColor then
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
        
        if NotPlater.ColorManager then
            NotPlater.ColorManager:ClearFrameColorCache(frame)
        end
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
            -- Clear existing color data
            if NotPlater.ColorManager then
                NotPlater.ColorManager:ClearFrameColorCache(frame)
            end
            
            -- Force immediate update
            self:UpdateFrameColor(frame)
        end
    end
end