-- modules/providers/colorProviders.lua
-- Modular color provider implementations

if not NotPlater then return end

local ColorProviders = {}
NotPlater.ColorProviders = ColorProviders

-- Local references
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitSelectionColor = UnitSelectionColor

-- Initialize color providers
function ColorProviders:Initialize()
    -- Providers are registered through ColorManager
end

-- Class color provider
function ColorProviders:ClassColorProvider(frame, playerName)
    if not NotPlater.db.profile.threat.nameplateColors.general.useClassColors then
        return nil, nil
    end
    
    -- Use ColorManager's implementation
    if NotPlater.ColorManager then
        return NotPlater.ColorManager:GetClassColorFromAllSources(frame, playerName)
    end
    
    return nil, nil
end

-- Reaction color provider
function ColorProviders:ReactionColorProvider(frame, playerName)
    if not frame.unit or not UnitExists(frame.unit) then
        return nil, nil
    end
    
    local r, g, b = UnitSelectionColor(frame.unit)
    if r and g and b then
        return {r = r, g = g, b = b}, "reaction"
    end
    
    return nil, nil
end

-- Default color provider
function ColorProviders:DefaultColorProvider(frame, playerName)
    local healthBarConfig = NotPlater.db.profile.healthBar
    if healthBarConfig and healthBarConfig.statusBar and healthBarConfig.statusBar.general then
        local color = healthBarConfig.statusBar.general.color
        return {
            r = color[1],
            g = color[2],
            b = color[3]
        }, "default"
    end
    
    return {r = 0.5, g = 0.5, b = 1}, "fallback"
end

-- Manual override provider (for future custom colors per unit)
function ColorProviders:ManualOverrideProvider(frame, playerName)
    -- Check if frame has a manual color override
    if frame.manualColorOverride then
        return frame.manualColorOverride, "manual"
    end
    
    -- Future: Check saved manual colors by player name
    -- if NotPlater.db.profile.manualColors and NotPlater.db.profile.manualColors[playerName] then
    --     return NotPlater.db.profile.manualColors[playerName], "manual"
    -- end
    
    return nil, nil
end

-- Threat color provider (handled by threat module)
function ColorProviders:ThreatColorProvider(frame, playerName)
    -- This is handled by the ThreatProvider module
    if NotPlater.ThreatProvider then
        return NotPlater.ThreatProvider:GetThreatColor(frame)
    end
    
    return nil, nil
end

-- Target highlight color provider
function ColorProviders:TargetColorProvider(frame, playerName)
    -- Special coloring for target
    if NotPlater:IsTarget(frame) then
        local targetConfig = NotPlater.db.profile.target
        if targetConfig and targetConfig.general and targetConfig.general.useTargetColor then
            local color = targetConfig.general.targetColor
            if color then
                return {
                    r = color[1],
                    g = color[2],
                    b = color[3]
                }, "target"
            end
        end
    end
    
    return nil, nil
end