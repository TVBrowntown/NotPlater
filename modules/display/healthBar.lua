if( not NotPlater ) then return end

function NotPlater:HealthOnValueChanged(oldHealthBar, value)
	local _, maxValue = oldHealthBar:GetMinMaxValues()
	local healthBarConfig = self.db.profile.healthBar

	-- Validate input values to prevent display issues
	if not value or not maxValue or maxValue <= 0 then
		return
	end
	
	-- Clamp value to valid range
	value = math.max(0, math.min(value, maxValue))

	local healthFrame = oldHealthBar.healthBar
	if not healthFrame then
		return
	end
	
	-- Only update if value actually changed
	if healthFrame.lastValue == value and healthFrame.lastMaxValue == maxValue then
		return
	end
	
	-- Set min/max values before setting current value
	healthFrame:SetMinMaxValues(0, maxValue)
	healthFrame:SetValue(value)
	
	-- Cache the values
	healthFrame.lastValue = value
	healthFrame.lastMaxValue = maxValue

	-- Throttle text updates to improve performance
	local currentTime = GetTime()
	if not healthFrame.lastTextUpdate then
		healthFrame.lastTextUpdate = 0
	end
	
	-- Only update text every 0.1 seconds
	if healthFrame.healthText and (currentTime - healthFrame.lastTextUpdate) >= 0.1 then
		healthFrame.lastTextUpdate = currentTime
		
		local displayType = healthBarConfig.healthText.general.displayType
		
		if displayType == "minmax" then
			if maxValue == 100 then
				healthFrame.healthText:SetFormattedText("%d%% / %d%%", value, maxValue)
			else
				if maxValue > 1000 then
					if value > 1000 then
						healthFrame.healthText:SetFormattedText("%.1fk / %.1fk", value / 1000, maxValue / 1000)
					else
						healthFrame.healthText:SetFormattedText("%d / %.1fk", value, maxValue / 1000)
					end
				else
					healthFrame.healthText:SetFormattedText("%d / %d", value, maxValue)
				end
			end
		elseif displayType == "both" then
			local percentage = math.floor(value/maxValue * 100)
			if value > 1000 then
				healthFrame.healthText:SetFormattedText("%.1fk (%d%%)", value/1000, percentage)
			else
				healthFrame.healthText:SetFormattedText("%d (%d%%)", value, percentage)
			end
		elseif displayType == "percent" then
			healthFrame.healthText:SetFormattedText("%d%%", math.floor(value / maxValue * 100))
		else
			healthFrame.healthText:SetText("")
		end
	end

	self:ThreatCheck(oldHealthBar:GetParent())
end

function NotPlater:ScaleHealthBar(healthFrame, isTarget)
	local scaleConfig = self.db.profile.target.general.scale
	if scaleConfig.healthBar then
    	local healthBarConfig = self.db.profile.healthBar
		local scalingFactor = isTarget and scaleConfig.scalingFactor or 1
		self:ScaleGeneralisedStatusBar(healthFrame, scalingFactor, healthBarConfig.statusBar)
		self:ScaleGeneralisedText(healthFrame.healthText, scalingFactor, healthBarConfig.healthText)
	end
end

function NotPlater:HealthBarOnShow(oldHealthBar)
	-- Safety checks
	if not oldHealthBar or not oldHealthBar.healthBar then
		return
	end
	
	-- Check if oldHealthBar has GetStatusBarColor method (i.e., is actually a StatusBar)
	if oldHealthBar.GetStatusBarColor then
		local r, g, b, a = oldHealthBar:GetStatusBarColor()
		if r and g and b then
			oldHealthBar.healthBar:SetStatusBarColor(r, g, b, a or 1)
		else
			-- Fallback to default health bar color if no color is available
			local healthBarConfig = self.db.profile.healthBar
			if healthBarConfig and healthBarConfig.statusBar and healthBarConfig.statusBar.general then
				oldHealthBar.healthBar:SetStatusBarColor(self:GetColor(healthBarConfig.statusBar.general.color))
			end
		end
	else
		-- oldHealthBar is not a StatusBar frame, use default color
		local healthBarConfig = self.db.profile.healthBar
		if healthBarConfig and healthBarConfig.statusBar and healthBarConfig.statusBar.general then
			oldHealthBar.healthBar:SetStatusBarColor(self:GetColor(healthBarConfig.statusBar.general.color))
		end
	end
	
	-- Set up highlight texture
	if oldHealthBar.healthBar.highlightTexture then
		oldHealthBar.healthBar.highlightTexture:SetAllPoints(oldHealthBar.healthBar)
	end
end

function NotPlater:ConfigureHealthBar(frame, oldHealthBar)
	-- Safety checks
	if not frame or not frame.healthBar then
		return
	end
	
	local healthBarConfig = self.db.profile.healthBar
	local healthFrame = frame.healthBar
	
	-- Configure statusbar
	self:ConfigureGeneralisedStatusBar(healthFrame, healthBarConfig.statusBar)

	-- Set points
	healthFrame:ClearAllPoints()
	self:SetSize(healthFrame, healthBarConfig.statusBar.size.width, healthBarConfig.statusBar.size.height)
	healthFrame:SetPoint("TOP", 0, self.db.profile.stacking.margin.yStacking)

	-- Set health text
	self:ConfigureGeneralisedText(healthFrame.healthText, healthFrame, healthBarConfig.healthText)

	-- Set Mouseover highlight
	frame.highlightTexture:SetAlpha(self.db.profile.target.general.mouseoverHighlight.opacity)
	if self.db.profile.target.general.mouseoverHighlight.enable then
		frame.highlightTexture:SetTexture(self.SML:Fetch(self.SML.MediaType.STATUSBAR, healthBarConfig.statusBar.general.texture))
	else
		frame.highlightTexture:SetTexture(0, 0, 0, 0)
	end

	-- Call HealthBarOnShow with safety checks
	if oldHealthBar then
		self:HealthBarOnShow(oldHealthBar)
	end
	
	-- Call HealthOnValueChanged with safety checks
	if oldHealthBar and oldHealthBar.GetValue and oldHealthBar.GetMinMaxValues then
		-- Check if it's a proper StatusBar with the required methods
		local success, value = pcall(function() return oldHealthBar:GetValue() end)
		if success and value then
			self:HealthOnValueChanged(oldHealthBar, value)
		else
			-- Set default values if we can't get them from oldHealthBar
			local minVal, maxVal = 0, 100
			if healthFrame.SetMinMaxValues and healthFrame.SetValue then
				healthFrame:SetMinMaxValues(minVal, maxVal)
				healthFrame:SetValue(maxVal) -- Default to full health
				
				-- Update health text with default values
				if healthFrame.healthText then
					local displayType = healthBarConfig.healthText.general.displayType
					if displayType == "minmax" then
						healthFrame.healthText:SetFormattedText("%d / %d", maxVal, maxVal)
					elseif displayType == "both" then
						healthFrame.healthText:SetFormattedText("%d (100%%)", maxVal)
					elseif displayType == "percent" then
						healthFrame.healthText:SetText("100%")
					else
						healthFrame.healthText:SetText("")
					end
				end
			end
		end
	else
		-- No valid oldHealthBar, set up with default values for simulator
		if healthFrame.SetMinMaxValues and healthFrame.SetValue then
			local minVal, maxVal = 0, 30000 -- Default simulator values
			healthFrame:SetMinMaxValues(minVal, maxVal)
			healthFrame:SetValue(maxVal)
			
			-- Update health text
			if healthFrame.healthText then
				local displayType = healthBarConfig.healthText.general.displayType
				if displayType == "minmax" then
					healthFrame.healthText:SetFormattedText("%.1fk / %.1fk", maxVal/1000, maxVal/1000)
				elseif displayType == "both" then
					healthFrame.healthText:SetFormattedText("%.1fk (100%%)", maxVal/1000)
				elseif displayType == "percent" then
					healthFrame.healthText:SetText("100%")
				else
					healthFrame.healthText:SetText("")
				end
			end
		end
	end
end

function NotPlater:ConstructHealthBar(frame, oldHealthBar)
	-- Don't reconstruct if already done
	if frame.healthBar then
		return
	end

	-- Construct statusbar components
	local healthFrame = CreateFrame("StatusBar", "$parentHealthBar", frame)
	self:ConstructGeneralisedStatusBar(healthFrame)

    -- Create health text
    healthFrame.healthText = healthFrame:CreateFontString(nil, "ARTWORK")

	-- Create or reference Mouseover highlight
	if not frame.highlightTexture then
		-- Create highlightTexture if it doesn't exist yet (for simulator)
		frame.highlightTexture = frame:CreateTexture(nil, "ARTWORK")
	end
	frame.highlightTexture:SetBlendMode("ADD")
	healthFrame.highlightTexture = frame.highlightTexture

	-- Hook to set health text (only if not already hooked)
	if not oldHealthBar.npHealthHooked then
		self:HookScript(oldHealthBar, "OnValueChanged", "HealthOnValueChanged")
		oldHealthBar.npHealthHooked = true
	end

	oldHealthBar.healthBar = healthFrame
	frame.healthBar = healthFrame
end