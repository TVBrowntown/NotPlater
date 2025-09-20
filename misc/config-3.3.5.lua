if not NotPlater then return end

local addonName, addonShared = ...

local Config = NotPlater:NewModule("Config")
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")
local L = NotPlaterLocals

local ssplit = string.split
local sgmatch = string.gmatch
local sformat = string.format
local tinsert = table.insert
local tonumber = tonumber
local ipairs = ipairs
local unpack = unpack
local GameTooltip = GameTooltip
local SlashCmdList = SlashCmdList
local InterfaceOptionsFrame = InterfaceOptionsFrame
local UIParent = UIParent

local SML, registered, options, config, dialog

NotPlater.oppositeAnchors = {
	["LEFT"] = "RIGHT",
	["RIGHT"] = "LEFT",
	["CENTER"] = "CENTER",
	["BOTTOM"] = "TOP",
	["TOP"] = "BOTTOM",
	["TOPRIGHT"] = "BOTTOMLEFT",
	["BOTTOMLEFT"] = "TOPRIGHT",
	["TOPLEFT"] = "BOTTOMRIGHT",
	["BOTTOMRIGHT"] = "TOPLEFT",
}

local TEXTURE_BASE_PATH = [[Interface\Addons\]]..addonName..[[\images\statusbarTextures\]]
local textures = {"NotPlater Default", "NotPlater Background", "NotPlater HealthBar", "Flat", "BarFill", "Banto", "Smooth", "Perl", "Glaze", "Charcoal", "Otravi", "Striped", "LiteStep"}

NotPlater.defaultHighlightTexture = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\selection_indicator3]] 
NotPlater.targetIndicators = {
	["NONE"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\UI-Achievement-WoodBorder-Corner]],
		coords = {{.9, 1, .9, 1}, {.9, 1, .9, 1}, {.9, 1, .9, 1}, {.9, 1, .9, 1}}, --texcoords, support 4 or 8 coords method
		desaturated = false,
		width = 10,
		height = 10,
		x = 1,
		y = 1,
	},
	
	["Magneto"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\RelicIconFrame]],
		coords = {{0, .5, 0, .5}, {0, .5, .5, 1}, {.5, 1, .5, 1}, {.5, 1, 0, .5}},
		desaturated = false,
		width = 8,
		height = 10,
		autoScale = true,
		x = 2,
		y = 2,
	},
	
	["Gray Bold"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\UI-Icon-QuestBorder]],
		coords = {{0, .5, 0, .5}, {0, .5, .5, 1}, {.5, 1, .5, 1}, {.5, 1, 0, .5}},
		desaturated = true,
		width = 10,
		height = 10,
		autoScale = true,
		x = 2,
		y = 2,
	},
	
	["Pins"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\UI-ItemSockets]],
		coords = {{145/256, 161/256, 3/256, 19/256}, {145/256, 161/256, 19/256, 3/256}, {161/256, 145/256, 19/256, 3/256}, {161/256, 145/256, 3/256, 19/256}},
		desaturated = 1,
		width = 4,
		height = 4,
		autoScale = false,
		x = 2,
		y = 2,
	},

	["Silver"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\PETBATTLEHUD]],
		coords = {
			{336/512, 356/512, 454/512, 474/512}, 
			{336/512, 356/512, 474/512, 495/512}, 
			{356/512, 377/512, 474/512, 495/512}, 
			{356/512, 377/512, 454/512, 474/512}
		}, --848 889 454 495
		desaturated = false,
		width = 6,
		height = 6,
		autoScale = true,
		x = 1,
		y = 1,
	},
	
	["Ornament"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\PETJOURNAL]],
		coords = {
			{124/512, 161/512, 71/512, 99/512}, 
			{119/512, 156/512, 29/512, 57/512}
		},
		desaturated = false,
		width = 18,
		height = 12,
		wscale = 1,
		hscale = 1.2,
		autoScale = true,
		x = 14,
		y = 0,
	},
	
	["Golden"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\Artifacts]],
		coords = {
			{137/512, (137+29)/512, 408/512, 466/512},
			{(137+30)/512, 195/512, 408/512, 466/512},
		},
		desaturated = false,
		width = 8,
		height = 12,
		wscale = 1,
		hscale = 1.2,
		autoScale = true,
		x = 0,
		y = 0,
	},

	["Ornament Gray"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\challenges-besttime-bg]],
		coords = {
			{89/512, 123/512, 0, 1},
			{123/512, 89/512, 0, 1},
		},
		desaturated = false,
		width = 8,
		height = 12,
		alpha = 0.7,
		wscale = 1,
		hscale = 1.2,
		autoScale = true,
		x = 0,
		y = 0,
		color = {r = 1, g = 0, b = 0},
	},

	["Epic"] = {
		path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\WowUI_Horizontal_Frame]],
		coords = {
			{30/256, 40/256, 15/64, 49/64},
			{40/256, 30/256, 15/64, 49/64}, 
		},
		desaturated = false,
		width = 6,
		height = 12,
		wscale = 1,
		hscale = 1.2,
		autoScale = true,
		x = 3,
		y = 0,
		blend = "ADD",
	},
	
	["Arrow"] = {
        path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\arrow_single_right_64]],
        coords = {
            {0, 1, 0, 1}, 
            {1, 0, 0, 1}
        },
        desaturated = false,
        width = 20,
        height = 20,
        x = 28,
        y = 0,
		wscale = 1.5,
		hscale = 2,
		autoScale = true,
        blend = "ADD",
        color = {r = 1, g = 1, b = 1},
    },
	
	["Arrow Thin"] = {
        path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\arrow_thin_right_64]],
        coords = {
            {0, 1, 0, 1}, 
            {1, 0, 0, 1}
        },
        desaturated = false,
        width = 20,
        height = 20,
        x = 28,
        y = 0,
		wscale = 1.5,
		hscale = 2,
		autoScale = true,
        blend = "ADD",
        color = {r = 1, g = 1, b = 1},
    },
	
	["Double Arrows"] = {
        path = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\arrow_double_right_64]],
        coords = {
            {0, 1, 0, 1}, 
            {1, 0, 0, 1}
        },
        desaturated = false,
        width = 20,
        height = 20,
        x = 28,
        y = 0,
		wscale = 1.5,
		hscale = 2,
		autoScale = true,
        blend = "ADD",
        color = {r = 1, g = 1, b = 1},
    },
}

local HIGHLIGHT_BASE_PATH = [[Interface\AddOns\]]..addonName..[[\images\targetBorders\]]
NotPlater.targetHighlights = {
	[HIGHLIGHT_BASE_PATH .. "selection_indicator1"] =  "Highlight 1",
	[HIGHLIGHT_BASE_PATH .. "selection_indicator2"] =  "Highlight 2",
	[HIGHLIGHT_BASE_PATH .. "selection_indicator3"] =  "Highlight 3",
	[HIGHLIGHT_BASE_PATH .. "selection_indicator4"] =  "Highlight 4",
	[HIGHLIGHT_BASE_PATH .. "selection_indicator5"] =  "Highlight 5",
	[HIGHLIGHT_BASE_PATH .. "selection_indicator6"] =  "Highlight 6",
	[HIGHLIGHT_BASE_PATH .. "selection_indicator7"] =  "Highlight 7",
	[HIGHLIGHT_BASE_PATH .. "selection_indicator8"] =  "Highlight 8"
}


local function GetAnchors(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hHalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vHalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vHalf..hHalf, frame, (vHalf == "TOP" and "BOTTOM" or "TOP")..hHalf
end

local function DrawMinimapTooltip()
    local tooltip = GameTooltip
    tooltip:ClearLines()
    tooltip:AddDoubleLine("NotPlater", NotPlater.revision or "2.0.0")
    tooltip:AddLine(" ")
    tooltip:AddLine(L["|cffeda55fLeft-Click|r to toggle the config window"], 0.2, 1, 0.2)
    tooltip:AddLine(L["|cffeda55fRight-Click|r to toggle the simulator frame"], 0.2, 1, 0.2)
    tooltip:AddLine(L["|cffeda55fMiddle-Click|r to toggle the minimap icon"], 0.2, 1, 0.2);
    tooltip:Show()
end

local function ToggleMinimap()
    NotPlaterDB.minimap.hide = not NotPlaterDB.minimap.hide
    if NotPlaterDB.minimap.hide then
        LDBIcon:Hide("NotPlater");
        NotPlater:Print(L["Use /np minimap to show the minimap icon again"])
    else
        LDBIcon:Show("NotPlater");
    end
end

local tooltipUpdateFrame = CreateFrame("Frame")
local Broker_NotPlater = LDB:NewDataObject("NotPlater", {
    type = "launcher",
    text = "NotPlater",
    icon = "Interface\\AddOns\\"..addonName.."\\images\\logo",
    OnClick = function(self, button)
		if(button == "LeftButton") then
			Config:ToggleConfig()
        elseif(button == "RightButton") then
			NotPlater:ToggleSimulatorFrame()
        else -- "MiddleButton"
            ToggleMinimap()
        end
        DrawMinimapTooltip()
    end,
    OnEnter = function(self)
        local elapsed = 0
        local delay = 1
        tooltipUpdateFrame:SetScript("OnUpdate", function(self, elap)
            elapsed = elapsed + elap
            if(elapsed > delay) then
                elapsed = 0
                DrawMinimapTooltip()
            end
        end);
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint(GetAnchors(self))
        DrawMinimapTooltip()
    end,
    OnLeave = function(self)
        tooltipUpdateFrame:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end,
})

function Config:OnInitialize()
	config = LibStub("AceConfig-3.0")
	dialog = LibStub("AceConfigDialog-3.0")
	
	SML = LibStub:GetLibrary("LibSharedMedia-3.0")
	for _, statusBarTexture in ipairs(textures) do
		SML:Register(SML.MediaType.STATUSBAR, statusBarTexture, TEXTURE_BASE_PATH .. statusBarTexture)
	end

	NotPlaterDB.minimap = NotPlaterDB.minimap or {hide = false}
	LDBIcon:Register("NotPlater", Broker_NotPlater, NotPlaterDB.minimap)
end

local function SetValue(...)
	local args = {...}
	local numArgs = #args
	
	-- Safety check
	if not NotPlater.db or not NotPlater.db.profile then
		return
	end
	
	local current = NotPlater.db.profile
	
	-- Navigate to the target location, creating tables as needed
	for i = 1, numArgs - 1 do
		local key = args[i]
		if not current[key] then
			current[key] = {}
		end
		current = current[key]
	end
	
	-- Set the final value
	local finalKey = args[numArgs - 1]
	local value = args[numArgs]
	
	if finalKey and current then
		current[finalKey] = value
		NotPlater:EnhancedReload()
	end
end

local function GetValue(...)
	local args = {...}
	local numArgs = #args
	
	-- Safety check
	if not NotPlater.db or not NotPlater.db.profile then
		return nil
	end
	
	local current = NotPlater.db.profile
	
	-- Navigate to the target value
	for i = 1, numArgs do
		local key = args[i]
		if not current or not current[key] then
			return nil
		end
		current = current[key]
	end
	
	-- Handle table vs single value
	if type(current) == "table" then
		-- Check if it's a color table with r,g,b values
		if current.r and current.g and current.b then
			return current.r, current.g, current.b, current.a or 1
		end
		-- Otherwise try to unpack if it's an array
		local success, result = pcall(unpack, current)
		if success then
			return result
		end
		return current
	else
		return current
	end
end

local function LoadOptions()
	options = {}
	options.type = "group"
	options.name = "NotPlater"
	options.args = {}
	
	-- Helper function to ensure config structure exists
	local function EnsureConfigPath(...)
		local path = {...}
		local current = NotPlater.db.profile
		for i = 1, #path do
			if not current[path[i]] then
				current[path[i]] = {}
			end
			current = current[path[i]]
		end
		return current
	end
	
	-- Enhanced GetValue that creates missing structure
	local function EnhancedGetValue(info)
		if not NotPlater.db or not NotPlater.db.profile then
			return nil
		end
		
		local current = NotPlater.db.profile
		for i = 1, #info do
			if not current[info[i]] then
				return nil
			end
			current = current[info[i]]
		end
		
		if type(current) == "table" then
			-- Handle color tables
			if current.r and current.g and current.b then
				return current.r, current.g, current.b, current.a or 1
			end
			-- Try to unpack arrays
			local success, result = pcall(unpack, current)
			if success then
				return result
			end
		end
		
		return current
	end
	
	-- Enhanced SetValue that creates missing structure
	local function EnhancedSetValue(info, ...)
		if not NotPlater.db or not NotPlater.db.profile then
			return
		end
		
		local values = {...}
		local current = NotPlater.db.profile
		
		-- Navigate to parent, creating structure as needed
		for i = 1, #info - 1 do
			if not current[info[i]] then
				current[info[i]] = {}
			end
			current = current[info[i]]
		end
		
		-- Set the value
		local key = info[#info]
		if #values > 1 then
			current[key] = values
		else
			current[key] = values[1]
		end
		
		-- Trigger reload
		if NotPlater.EnhancedReload then
			NotPlater:EnhancedReload()
		else
			NotPlater:Reload()
		end
	end
	
	-- Threat Icon options
	options.args.threatIcon = {
	    order = 0.5,
	    type = "group",
	    name = L["Threat Icon"],
	    get = EnhancedGetValue,
	    set = EnhancedSetValue,
	    args = NotPlater.ConfigPrototypes.ThreatIcon
	}
	
	-- Health Bar options
	options.args.healthBar = {
		type = "group",
		order = 1,
		name = L["Health Bar"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		childGroups = "tab",
		args = {
			statusBar = {
				order = 0,
				type = "group",
				name = L["Status Bar"],
				args = NotPlater.ConfigPrototypes.HealthBar,
			},
			healthText = {
				order = 1,
				type = "group",
				name = L["Health Text"],
				args = NotPlater.ConfigPrototypes.HealthText
			},
		},
	}
	
	-- Cast Bar options
	options.args.castBar = {
		type = "group",
		order = 2,
		name = L["Cast Bar"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		childGroups = "tab",
		args =  {
			statusBar = {
				order = 0,
				type = "group",
				name = L["Status Bar"],
				args = NotPlater.ConfigPrototypes.CastBar,
			},
			spellIcon = {
				order = 1,
				type = "group",
				name = L["Spell Icon"],
				args = NotPlater.ConfigPrototypes.CastBarIcon
			},
			spellTimeText = {
				order = 2,
				type = "group",
				name = L["Spell Time Text"],
				args = NotPlater.ConfigPrototypes.SpellTimeText
			},
			spellNameText = {
				order = 3,
				type = "group",
				name = L["Spell Name Text"],
				args = NotPlater.ConfigPrototypes.SpellNameText
			},
		},
	}
	
	-- Name Text options
	options.args.nameText = {
		order = 3,
		type = "group",
		name = L["Name Text"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		args = NotPlater.ConfigPrototypes.NameText
	}
	
	-- Level Text options
	options.args.levelText = {
		order = 4,
		type = "group",
		name = L["Level Text"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		args = NotPlater.ConfigPrototypes.LevelText
	}
	
	-- Raid Icon options
	options.args.raidIcon = {
		order = 5,
		type = "group",
		name = L["Raid Icon"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		args = NotPlater.ConfigPrototypes.Icon
	}
	
	-- Boss Icon options
	options.args.bossIcon = {
		order = 6,
		type = "group",
		name = L["Boss Icon"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		args = NotPlater.ConfigPrototypes.Icon
	}
	
	-- Target options
	options.args.target = {
		order = 7,
		type = "group",
		name = L["Target"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		childGroups = "tab",
		args = {
			general = {
				order = 0,
				type = "group",
				name = L["General"],
				args = NotPlater.ConfigPrototypes.Target
			},
			targetTargetText = {
				order = 8,
				type = "group",
				name = L["Target-Target Text"],
				args = NotPlater.ConfigPrototypes.TargetTargetText
			}
		}
	}
	
	-- Add cache options only if prototypes exist
	if NotPlater.ConfigPrototypes.GuildCache then
		options.args.guildCache = {
			order = 8,
			type = "group",
			name = L["Guild Cache"],
			-- These use their own get/set functions from the prototypes
			args = NotPlater.ConfigPrototypes.GuildCache
		}
	end

	if NotPlater.ConfigPrototypes.PartyRaidCache then
		options.args.partyRaidCache = {
		    order = 9,
		    type = "group",
		    name = L["Party/Raid Cache"],
		    -- These use their own get/set functions from the prototypes
		    args = NotPlater.ConfigPrototypes.PartyRaidCache
		}
	end

	if NotPlater.ConfigPrototypes.RecentlySeenCache then
		options.args.recentlySeenCache = {
			order = 10,
			type = "group",
			name = L["Recently Seen Cache"],
			-- These use their own get/set functions from the prototypes
			args = NotPlater.ConfigPrototypes.RecentlySeenCache
		}
	end
	
	-- Simulator options
	options.args.simulator = {
		order = 11,
		type = "group",
		name = L["Simulator"],
		get = EnhancedGetValue,
		set = EnhancedSetValue,
		args = NotPlater.ConfigPrototypes.Simulator
	}

	-- Profile options
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(NotPlater.db)
	options.args.profile.order = 12
	
	-- Ensure all default config paths exist
	if NotPlater.db and NotPlater.db.profile then
		-- Ensure threat icon config exists
		EnsureConfigPath("threatIcon", "general")
		EnsureConfigPath("threatIcon", "size")
		EnsureConfigPath("threatIcon", "position")
		
		-- Ensure health bar config exists
		EnsureConfigPath("healthBar", "statusBar", "general")
		EnsureConfigPath("healthBar", "statusBar", "background")
		EnsureConfigPath("healthBar", "statusBar", "size")
		EnsureConfigPath("healthBar", "statusBar", "border")
		EnsureConfigPath("healthBar", "coloring")
		EnsureConfigPath("healthBar", "coloring", "reactionColors")
		EnsureConfigPath("healthBar", "coloring", "classColors")
		EnsureConfigPath("healthBar", "healthText", "general")
		EnsureConfigPath("healthBar", "healthText", "position")
		EnsureConfigPath("healthBar", "healthText", "shadow")
		
		-- Set defaults if missing
		if not NotPlater.db.profile.threatIcon.general.enable then
			NotPlater.db.profile.threatIcon.general.enable = true
		end
		if not NotPlater.db.profile.threatIcon.general.opacity then
			NotPlater.db.profile.threatIcon.general.opacity = 1
		end
		if not NotPlater.db.profile.threatIcon.general.visibility then
			NotPlater.db.profile.threatIcon.general.visibility = "combat"
		end
		if not NotPlater.db.profile.threatIcon.size.width then
			NotPlater.db.profile.threatIcon.size.width = 36
		end
		if not NotPlater.db.profile.threatIcon.size.height then
			NotPlater.db.profile.threatIcon.size.height = 36
		end
		if not NotPlater.db.profile.threatIcon.position.anchor then
			NotPlater.db.profile.threatIcon.position.anchor = "RIGHT"
		end
		if not NotPlater.db.profile.threatIcon.position.xOffset then
			NotPlater.db.profile.threatIcon.position.xOffset = -32
		end
		if not NotPlater.db.profile.threatIcon.position.yOffset then
			NotPlater.db.profile.threatIcon.position.yOffset = 0
		end
	end
end

function Config:ToggleConfig()
	if dialog.OpenFrames["NotPlater"] then
		if NotPlater.db.profile.simulator.general.showOnConfig then
			NotPlater:HideSimulatorFrame()
		end
		dialog:Close("NotPlater")
	else
		self:OpenConfig()
	end
end

function Config:OpenConfig()
	if( not registered ) then
		-- Ensure prototypes are loaded first
		if not NotPlater.ConfigPrototypes or not NotPlater.ConfigPrototypes.HealthBar then
			NotPlater.ConfigPrototypes:LoadConfigPrototypes()
		end
		
		-- Ensure config structure exists
		if NotPlater.db and NotPlater.db.profile and NotPlater.MigrateConfig then
			NotPlater:MigrateConfig()
		end
		
		if( not options ) then
			LoadOptions()
		end

		-- Validate that we have the necessary data
		if not options or not options.args then
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Error loading config options")
			return
		end

		config:RegisterOptionsTable("NotPlater", options)
		dialog:SetDefaultSize("NotPlater", 850, 650)
		registered = true
	end
	
	if NotPlater.db and NotPlater.db.profile and NotPlater.db.profile.simulator and 
	   NotPlater.db.profile.simulator.general and NotPlater.db.profile.simulator.general.showOnConfig then
		NotPlater:ShowSimulatorFrame()
	end
	
	dialog:Open("NotPlater")
end

-- Slash commands
SLASH_NOTPLATER1 = "/notplater"
SLASH_NOTPLATER2 = "/np"
SlashCmdList["NOTPLATER"] = function(input)
	local args, msg = {}, nil

    for v in sgmatch(input, "%S+") do
        if not msg then
			msg = v
        else
			tinsert(args, v)
        end
    end

    if msg == "minimap" then
        ToggleMinimap()
    elseif msg == "simulator" then
		NotPlater:ToggleSimulatorFrame()
    elseif msg == "export" then
        NotPlater:ExportSettingsString()
    elseif msg == "import" then
        NotPlater:ShowImportFrame()
    elseif msg == "reset" then
        if NotPlater.ResetConfig then
            NotPlater:ResetConfig()
        else
            NotPlater:Print("Reset function not available")
        end
    elseif msg == "migrate" then
        if NotPlater.MigrateConfig then
            NotPlater:MigrateConfig()
            NotPlater:Print("Configuration migration completed")
        else
            NotPlater:Print("Migration function not available")
        end
	elseif msg == "help" then
        NotPlater:PrintHelp()
	else
		Config:ToggleConfig()
    end
end

-- Update the help function
function NotPlater:PrintHelp()
    self:Print(L["Usage:"])
    self:Print(L["/np help - Show this message"])
    self:Print(L["/np config - Toggle the config window"])
    self:Print(L["/np simulator - Toggle the simulator frame"])
    self:Print(L["/np minimap - Toggle the minimap icon"])
    self:Print("/np export - Export settings as shareable string")
    self:Print("/np import - Import settings from string")
    self:Print("/np reset - Reset configuration to defaults")
    self:Print("/np migrate - Migrate old configuration to new format")
end