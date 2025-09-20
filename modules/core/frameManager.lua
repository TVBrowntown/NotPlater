-- modules/core/frameManager.lua
-- Centralized frame management and lifecycle

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
    local UPDATE_INTERVAL = 0.1
    local CLEANUP_INTERVAL = 30
    
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
    
    -- Get nameplate info
    local nameText = select(7, frame:GetRegions())
    local playerName = nameText and nameText:GetText()
    
    -- Immediate cache check for colors
    if playerName and NotPlater.CacheManager then
        NotPlater.CacheManager:CheckAllCaches(frame, playerName)
    end
    
    -- Update visual appearance
    if NotPlater.ColorManager then
        NotPlater.ColorManager:UpdateNameplateAppearance(frame)
    end
    
    -- Show cast bar if needed
    if NotPlater.CastBarOnShow then
        NotPlater:CastBarOnShow(frame)
    end
    
    -- Update stacking
    if NotPlater.StackingCheck then
        NotPlater:StackingCheck(frame)
    end
    
    -- Update threat components
    if NotPlater.ThreatComponentsOnShow then
        NotPlater:ThreatComponentsOnShow(frame)
    end
    
    -- Check if target
    if NotPlater.TargetCheck then
        NotPlater:TargetCheck(frame)
    end
    
    frame.targetChanged = true
end

-- Handle nameplate hide event
function FrameManager:OnNameplateHide(frame)
    -- Clear all cached data
    if NotPlater.ColorManager then
        NotPlater.ColorManager:ClearFrameColorCache(frame)
    end
    
    -- Clear threat cache
    frame.unit = nil
    frame.unitGUID = nil
    frame.wasTarget = nil
    
    -- Hide cast bar
    if frame.castBar then
        frame.castBar:Hide()
        frame.castBar.casting = nil
        frame.castBar.channeling = nil
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
    end
    
    -- Handle target changes
    if frame.targetChanged then
        if NotPlater.TargetCheck then
            NotPlater:TargetCheck(frame)
        end
        frame.targetChanged = nil
    end
    
    -- Update threat icon
    if NotPlater.db.profile.threatIcon and NotPlater.db.profile.threatIcon.general.enable then
        if NotPlater.UpdateThreatIcon then
            -- Try to find unit for threat calculation
            local nameText, levelText = select(7, frame:GetRegions())
            if nameText and levelText then
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
                    end
                end
            end
            
            if frame.unit then
                NotPlater:UpdateThreatIcon(frame)
            end
        end
    end
    
    -- Update colors if needed
    if not frame.unitClass and NotPlater.db.profile.threat.nameplateColors.general.useClassColors then
        local nameText = select(7, frame:GetRegions())
        local playerName = nameText and nameText:GetText()
        
        if playerName then
            -- Try cache checks
            local foundClass = false
            if NotPlater.CacheManager then
                foundClass = NotPlater.CacheManager:CheckAllCaches(frame, playerName)
            end
            
            -- Fallback to direct class check
            if not foundClass and NotPlater.ClassCheck then
                NotPlater:ClassCheck(frame)
            end
        end
    end
    
    -- Update target text
    if NotPlater.SetTargetTargetText then
        NotPlater:SetTargetTargetText(frame)
    end
    
    -- Handle alpha changes
    if isTarget then
        frame:SetAlpha(1)
    elseif NotPlater.db.profile.target.general.nonTargetAlpha.enable then
        frame:SetAlpha(NotPlater.db.profile.target.general.nonTargetAlpha.opacity)
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
            self:OnNameplateUpdate(frame)
        end
    end
end