if not NotPlater then return end

local addonName, addonShared = ...

local L = NotPlaterLocals

local tinsert = table.insert
local tsort = table.sort
local mrand = math.random
local mfmod = math.fmod
local tostring = tostring
local unpack = unpack
local UIParent = UIParent
local GameTooltip = GameTooltip
local GetTime = GetTime
local UnitGUID = UnitGUID

local simulatorFrameConstructed = false
local simulatorTextSet = false

local healthMin = 0
local healthMax = 30000
local castTime = 5000 -- in ms

local MAX_RAID_ICONS = 8
local RAID_ICON_BASE_PATH = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local BOSS_ICON_PATH = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local currentRaidIconNum = 1
local raidIconInterval = 5
local raidIconElapsed = raidIconInterval

function NotPlater:SimulatorFrameOnUpdate(elapsed)
    if not simulatorTextSet then
        self.defaultFrame.defaultLevelText:SetText(L["70"])
        self.defaultFrame.defaultLevelText:SetTextColor(1, 1, 0, 1)
        self.defaultFrame.defaultNameText:SetText(L["Playername"])
        simulatorTextSet = true
    end
    
    -- Cast bar simulation
    if not self.defaultFrame.castBar.casting and NotPlater.db.profile.castBar.statusBar.general.enable then
        local startTime = GetTime()
        local endTime = startTime + castTime
        NotPlater:SetCastBarNameText(self.defaultFrame, L["Spellname"])
        self.defaultFrame.castBar.value = 0
        self.defaultFrame.castBar.maxValue = (endTime - startTime) / 1000
        self.defaultFrame.castBar:SetMinMaxValues(0, self.defaultFrame.castBar.maxValue)
        self.defaultFrame.castBar:SetValue(self.defaultFrame.castBar.value)

        if self.defaultFrame.castBar.icon then
            self.defaultFrame.castBar.icon.texture:SetTexture("Interface\\Icons\\Temp")
        end
        self.defaultFrame.castBar.casting = true
        self.defaultFrame.castBar:Show()
    elseif not NotPlater.db.profile.castBar.statusBar.general.enable then
        self.defaultFrame.castBar.casting = false
    end

    -- Raid icon cycling
    if raidIconElapsed > raidIconInterval then
        self.defaultFrame.defaultRaidIcon:SetTexture(RAID_ICON_BASE_PATH .. tostring(currentRaidIconNum))
        self.defaultFrame.defaultBossIcon:SetTexture(RAID_ICON_BASE_PATH .. tostring(currentRaidIconNum))
        currentRaidIconNum = currentRaidIconNum + 1
        if currentRaidIconNum > MAX_RAID_ICONS then
            currentRaidIconNum = 1
        end
        raidIconElapsed = 0
    end
    raidIconElapsed = raidIconElapsed + elapsed
    
    -- Update threat icon if enabled
    if NotPlater.UpdateThreatIcon then
        NotPlater:UpdateThreatIcon(self.defaultFrame)
    end
    
    -- Update colors using ColorManager
    if NotPlater.ColorManager then
        NotPlater.ColorManager:UpdateNameplateAppearance(self.defaultFrame)
    end
end

function NotPlater:ToggleSimulatorFrame()
    if self.simulatorFrame and self.simulatorFrame:IsShown() then
        self.simulatorFrame:Hide()
    else
        self:ShowSimulatorFrame()
    end
end

function NotPlater:ShowSimulatorFrame()
    self:ConstructSimulatorFrame()
    self.simulatorFrame:Show()
end

function NotPlater:HideSimulatorFrame()
    if self.simulatorFrame then
        self.simulatorFrame:Hide()
    end
end

function NotPlater:SetSimulatorSize()
    local simulatorConfig = self.db.profile.simulator
    self:SetSize(self.simulatorFrame, simulatorConfig.size.width, simulatorConfig.size.height)
end

function NotPlater:SimulatorReload()
    self:SetSimulatorSize()
    self:PrepareFrame(self.simulatorFrame.defaultFrame)
    if self.simulatorFrame.defaultFrame.threatIcon then
        self:ConfigureThreatIcon(self.simulatorFrame.defaultFrame)
        self:UpdateThreatIcon(self.simulatorFrame.defaultFrame)
    end
end

function NotPlater:SimulatorFrameOnShow()
    NotPlater.simulatorFrame.defaultFrame.simulatedTarget = true
    NotPlater.simulatorFrame.defaultFrame.ignoreThreatCheck = true
    
    -- Store old functions for restoration
    NotPlater.oldIsTarget = NotPlater.IsTarget
    NotPlater.IsTarget = function(name, frame, ...)
        if frame and frame.simulatedTarget then return true end
        return NotPlater.oldIsTarget(name, frame, ...)
    end
    
    NotPlater.simulatorFrame.defaultFrame.ignoreStrataOptions = true
    NotPlater.oldSetNormalFrameStrata = NotPlater.SetNormalFrameStrata
    NotPlater.SetNormalFrameStrata = function(name, frame, ...)
        if frame and frame.ignoreStrataOptions then return true end
        NotPlater.oldSetNormalFrameStrata(name, frame, ...)
    end
    NotPlater.oldSetTargetFrameStrata = NotPlater.SetTargetFrameStrata
    NotPlater.SetTargetFrameStrata = function(name, frame, ...)
        if frame and frame.ignoreStrataOptions then return true end
        NotPlater.oldSetTargetFrameStrata(name, frame, ...)
    end
    NotPlater.oldReload = NotPlater.Reload
    NotPlater.Reload = function(...)
        NotPlater:SimulatorReload()
        NotPlater.oldReload(...)
    end
    NotPlater.simulatorFrame.defaultFrame:SetFrameStrata(NotPlater.simulatorFrame:GetFrameStrata())
end

function NotPlater:SimulatorFrameOnHide()
    if NotPlater.oldIsTarget then NotPlater.IsTarget = NotPlater.oldIsTarget end
    if NotPlater.oldSetNormalFrameStrata then NotPlater.SetNormalFrameStrata = NotPlater.oldSetNormalFrameStrata end
    if NotPlater.oldSetTargetFrameStrata then NotPlater.SetTargetFrameStrata = NotPlater.oldSetTargetFrameStrata end
    if NotPlater.oldReload then NotPlater.Reload = NotPlater.oldReload end
end

function NotPlater:ConstructSimulatorFrame()
    if simulatorFrameConstructed then return end
    simulatorFrameConstructed = true
    local simulatorFrame = CreateFrame("Frame", "NotPlaterSimulatorFrame", WorldFrame)
    self.simulatorFrame = simulatorFrame
    local simulatorFrameCloseButton = CreateFrame("Button", "NotPlaterSimulatorFrameCloseButton", simulatorFrame, "UIPanelCloseButton")
    simulatorFrameCloseButton:SetPoint("TOPRIGHT")
    simulatorFrame:SetMovable(true)
    simulatorFrame:EnableMouse(true)
    simulatorFrame:RegisterForDrag("LeftButton")
    simulatorFrame:SetScript("OnUpdate", NotPlater.SimulatorFrameOnUpdate)
    simulatorFrame:SetScript("OnHide", NotPlater.SimulatorFrameOnHide)
    simulatorFrame:SetScript("OnShow", NotPlater.SimulatorFrameOnShow)
    simulatorFrame:SetScript("OnDragStart", simulatorFrame.StartMoving)
    simulatorFrame:SetScript("OnDragStop", simulatorFrame.StopMovingOrSizing)
    simulatorFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["NotPlater Simulator Frame"])
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["|cffeda55fLeft-Click and Drag|r on the outer area to move the simulator frame"], 0.2, 1, 0.2)
        GameTooltip:Show()
    end)
    simulatorFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    simulatorFrame:SetFrameStrata("TOOLTIP")
    simulatorFrame:ClearAllPoints()
    self:SetSimulatorSize()
    simulatorFrame:SetPoint("CENTER", 4, -1)
    simulatorFrame:SetBackdrop({bgFile="Interface\\BUTTONS\\WHITE8X8", edgeFile="Interface\\BUTTONS\\WHITE8X8", tileSize=16, tile=true, edgeSize=2, insets = {left=4,right=4,top=4,bottom=4}})
    simulatorFrame:SetBackdropColor(0, 0, 0, 0)
    simulatorFrame:SetBackdropBorderColor(1, 1, 1, 0.3)
    simulatorFrame.outlineText = simulatorFrame:CreateFontString(nil, "ARTWORK")
    simulatorFrame.outlineText:SetFont(self.SML:Fetch(self.SML.MediaType.FONT, "Arial Narrow"), 16, "OUTLINE")
    simulatorFrame.outlineText:SetPoint("BOTTOM", simulatorFrame, 0, 2)
    simulatorFrame.outlineText:SetText(L["NotPlater Simulator Frame"])
    simulatorFrame.outlineText:SetAlpha(0.3)
    simulatorFrame.dragMeTexture = simulatorFrame:CreateTexture(nil, "BORDER")
    simulatorFrame.dragMeTexture:SetTexture("Interface\\AddOns\\".. addonName .."\\images\\drag")
    self:SetSize(simulatorFrame.dragMeTexture, 16, 16)
    simulatorFrame.dragMeTexture:SetPoint("TOPLEFT", simulatorFrame, 7, -7)
    simulatorFrame.dragMeTexture:SetAlpha(0.3)
    
    -- Create the main nameplate frame
    simulatorFrame.defaultFrame = CreateFrame("Button", "NotPlaterSimulatorDefaultFrame", simulatorFrame)
    simulatorFrame.defaultFrame:EnableMouse(true)
    simulatorFrame.defaultFrame:RegisterForClicks("AnyDown")
    simulatorFrame.defaultFrame:SetScript("OnClick", function (self, mouseButton)
        if mouseButton == "LeftButton" or mouseButton == "RightButton" then
            if self.simulatedTarget then
                self.simulatedTarget = false
            else
                self.simulatedTarget = true
            end
            self.targetChanged = true
        end
    end)
    self:SetSize(simulatorFrame.defaultFrame, 156.65, 39.16)
    simulatorFrame.defaultFrame:SetPoint("CENTER")

    -- Create StatusBar frames FIRST
    simulatorFrame.defaultFrame.defaultHealthFrame = CreateFrame("StatusBar", "NotPlaterSimulatorHealthFrame", simulatorFrame.defaultFrame)
    simulatorFrame.defaultFrame.defaultHealthFrame:SetMinMaxValues(healthMin, healthMax)
    simulatorFrame.defaultFrame.defaultHealthFrame:SetStatusBarColor(1, 0.109, 0, 1)

    -- Create ALL required textures
    local threatGlow = simulatorFrame.defaultFrame:CreateTexture(nil, "ARTWORK")
    local healthBorder = simulatorFrame.defaultFrame:CreateTexture(nil, "ARTWORK")
    local castBorder = simulatorFrame.defaultFrame:CreateTexture(nil, "ARTWORK")
    local castNoStop = simulatorFrame.defaultFrame:CreateTexture(nil, "ARTWORK")
    local spellIcon = simulatorFrame.defaultFrame:CreateTexture(nil, "ARTWORK")
    local highlightTexture = simulatorFrame.defaultFrame:CreateTexture(nil, "ARTWORK")
    local nameText = simulatorFrame.defaultFrame:CreateFontString(nil, "ARTWORK")
    local levelText = simulatorFrame.defaultFrame:CreateFontString(nil, "ARTWORK")
    local dangerSkull = simulatorFrame.defaultFrame:CreateTexture(nil, "BORDER")
    local bossIcon = simulatorFrame.defaultFrame:CreateTexture(nil, "BORDER")
    local raidIcon = simulatorFrame.defaultFrame:CreateTexture(nil, "BORDER")

    -- Store references
    simulatorFrame.defaultFrame.defaultThreatGlow = threatGlow
    simulatorFrame.defaultFrame.defaultHealthBorder = healthBorder
    simulatorFrame.defaultFrame.defaultCastBorder = castBorder
    simulatorFrame.defaultFrame.defaultCastNoStop = castNoStop
    simulatorFrame.defaultFrame.defaultSpellIcon = spellIcon
    simulatorFrame.defaultFrame.defaultHighlightTexture = highlightTexture
    simulatorFrame.defaultFrame.defaultNameText = nameText
    simulatorFrame.defaultFrame.defaultLevelText = levelText
    simulatorFrame.defaultFrame.dangerSkull = dangerSkull
    simulatorFrame.defaultFrame.defaultBossIcon = bossIcon
    simulatorFrame.defaultFrame.defaultRaidIcon = raidIcon

    -- Set up child frames
    local health = simulatorFrame.defaultFrame.defaultHealthFrame
    local cast = CreateFrame("StatusBar", "NotPlaterSimulatorCastFrame", simulatorFrame.defaultFrame)

    -- Construct all components
    self:ConstructHealthBar(simulatorFrame.defaultFrame, simulatorFrame.defaultFrame.defaultHealthFrame)
    self:ConstructThreatIcon(simulatorFrame.defaultFrame)
    self:ConstructCastBar(simulatorFrame.defaultFrame)
    self:ConstructTarget(simulatorFrame.defaultFrame)

    -- Prepare the frame
    self:PrepareFrame(simulatorFrame.defaultFrame)

    simulatorFrame.defaultFrame:SetScript("OnEnter", function(self)
        simulatorFrame.defaultFrame.highlightTexture:Show()
        self.defaultNameText:SetTextColor(1,0,0,1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["NotPlater Simulated Frame"])
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["|cffeda55fLeft-Click or Right-Click|r target/untarget the simulated frame"], 0.2, 1, 0.2)
        GameTooltip:Show()
    end)
    
    simulatorFrame.defaultFrame:SetScript("OnLeave", function(self)
        simulatorFrame.defaultFrame.highlightTexture:Hide()
        GameTooltip:Hide()
        self.defaultNameText:SetTextColor(1,1,1,1)
    end)

    simulatorFrame:Hide()
end