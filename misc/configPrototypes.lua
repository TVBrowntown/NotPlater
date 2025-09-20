if not NotPlater then return end

local L = NotPlaterLocals
local fontBorders = {[""] = L["None"], ["OUTLINE"] = L["Outline"], ["THICKOUTLINE"] = L["Thick Outline"], ["MONOCHROME"] = L["Monochrome"]}
local anchors = {["CENTER"] = L["Center"], ["BOTTOM"] = L["Bottom"], ["TOP"] = L["Top"], ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"], ["BOTTOMLEFT"] = L["Bottom Left"], ["TOPRIGHT"] = L["Top Right"], ["BOTTOMRIGHT"] = L["Bottom Right"], ["TOPLEFT"] = L["Top Left"]}
local frameStratas = {["BACKGROUND"] = L["Background"], ["LOW"] = L["Low"], ["MEDIUM"] = L["Medium"], ["HIGH"] = L["High"], ["DIALOG"] = L["Dialog"], ["FULLSCREEN"] = L["Fullscreen"], ["FULLSCREEN_DIALOG"] = L["Fullscreen Dialog"], ["TOOLTIP"] = L["Tooltip"]}
local drawLayers = {["BACKGROUND"] = L["Background"], ["BORDER"] = L["Border"], ["ARTWORK"] = L["Artwork"], ["OVERLAY"] = L["Overlay"], ["HIGHLIGHT"] = L["Highlight"]}

local ConfigPrototypes = {}
NotPlater.ConfigPrototypes = ConfigPrototypes

-- Return all registered SML textures
local function GetTextures()
    local textures = {}
    for _, name in pairs(NotPlater.SML:List(NotPlater.SML.MediaType.STATUSBAR)) do
        textures[name] = name
    end
    
    return textures
end

-- Return all registered SML fonts
local function GetFonts()
    local fonts = {}
    for _, name in pairs(NotPlater.SML:List(NotPlater.SML.MediaType.FONT)) do
        fonts[name] = name
    end
    
    return fonts
end

local function GetIndicators()
    local indicators = {}
    for name, _ in pairs(NotPlater.targetIndicators) do
        indicators[name] = name
    end
    
    return indicators
end

function ConfigPrototypes:GetGeneralisedPositionConfig()
    return {
        order = 1,
        type = "group",
        inline = true,
        name = L["Position"],
        args = {
            anchor = {
                order = 1,
                type = "select",
                name = L["Anchor"],
                values = anchors,
            },
            xOffset = {
                order = 2,
                type = "range",
                name = L["X Offset"],
                min = -100, max = 100, step = 1,
            },
            yOffset = {
                order = 3,
                type = "range",
                name = L["Y Offset"],
                min = -100, max = 100, step = 1,
            },
        },
    }
end

function ConfigPrototypes:GetGeneralisedSizeConfig()
    return {
        order = 1,
        type = "group",
        inline = true,
        name = L["Size"],
        args = {
            width = {
                order = 0,
                type = "range",
                name = L["Width"],
                min = 0, max = 500, step = 1,
            },
            height = {
                order = 1,
                type = "range",
                name = L["Height"],
                min = 0, max = 500, step = 1,
            },
        }
    }
end

function ConfigPrototypes:GetGeneralisedBackgroundConfig()
    return {
        order = 0.5,
        type = "group",
        inline = true,
        name = L["Background"],
        args = {
            enable = {
                order = 0,
                type = "toggle",
                name = L["Enable"],
            },
            color = {
                order = 1,
                type = "color",
                name = L["Color"],
                hasAlpha = true,
            },
            texture = {
                order = 2,
                type = "select",
                name = L["Texture"],
                values = GetTextures,
            },
        },
    }
end

function ConfigPrototypes:GetGeneralisedBorderConfig()
    return { 
        order = 2,
        type = "group",
        inline = true,
        name = L["Border"],
        args = {
            enable = {
                order = 0,
                type = "toggle",
                name = L["Enable"],
            },
            color = {
                order = 1,
                type = "color",
                name = L["Color"],
                hasAlpha = true,
            },
            thickness = {
                order = 2,
                type = "range",
                name = L["Thickness"],
                min = 1, max = 10, step = 1,
            },
        },
    }
end

function ConfigPrototypes:GetGeneralisedFontConfig()
    return {
        general = {
            order = 0,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                enable = {
                    order = 0,
                    width = "full",
                    type = "toggle",
                    name = L["Enable"],
                },
                name = {
                    order = 1,
                    type = "select",
                    name = L["Name"],
                    values = GetFonts,
                },
                size = {
                    order = 2,
                    type = "range",
                    name = L["Size"],
                    min = 1, max = 20, step = 1,
                },
                border = {
                    order = 3,
                    type = "select",
                    name = L["Border"],
                    values = fontBorders,
                },
            },
        },
        position = ConfigPrototypes:GetGeneralisedPositionConfig(),
        shadow = {
            order = 2,
            type = "group",
            inline = true,
            name = L["Shadow"],
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                    width = "full",
                },
                color = {
                    order = 1,
                    type = "color",
                    name = L["Color"],
                    hasAlpha = true,
                },
                xOffset = {
                    order = 2,
                    type = "range",
                    name = L["X Offset"],
                    min = -2, max = 2, step = 1,
                },
                yOffset = {
                    order = 3,
                    type = "range",
                    name = L["Y Offset"],
                    min = -2, max = 2, step = 1,
                },
            },
        },
    }
end

function ConfigPrototypes:GetGeneralisedColorFontConfig()
    local config = self:GetGeneralisedFontConfig()
    config.general.args.color = {
        order = 2,
        type = "color",
        name = L["Color"],
        hasAlpha = true,
    }

    return config
end

function ConfigPrototypes:GetGeneralisedStatusBarConfig()
    return {
        general = {
            order = 0.25,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                },
                texture = {
                    order = 2,
                    type = "select",
                    name = L["Texture"],
                    values = GetTextures,
                },
            },
        },
        background = ConfigPrototypes:GetGeneralisedBackgroundConfig(),
        size = ConfigPrototypes:GetGeneralisedSizeConfig(),
        border = ConfigPrototypes:GetGeneralisedBorderConfig()
    }
end

function ConfigPrototypes:GetGeneralisedIconConfig()
    return {
        general = {
            order = 0,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                opacity = {
                    order = 1,
                    type = "range",
                    name = L["Opacity"],
                    min = 0, max = 1, step = 0.01,
                },
            },
        },
        size = ConfigPrototypes:GetGeneralisedSizeConfig(),
        position = ConfigPrototypes:GetGeneralisedPositionConfig()
    }
end

function ConfigPrototypes:LoadConfigPrototypes()
    ConfigPrototypes.NameplateStacking = {
        header = {
            order = 0,
            name = L["Note: All settings here only work out of combat."],
            type = "header",
        },
        general = {
            order = 1,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                    desc = L["Only works if the nameplate is visible before you are in combat"],
                },
                overlappingCastbars = {
                    order = 0,
                    type = "toggle",
                    name = L["Overlapping Castbars"],
                },
            },
        },
        margin = {
            order = 2,
            type = "group",
            inline = true,
            name = L["Margin"],
            args = {
                xStacking = {
                    order = 0,
                    type = "range",
                    name = L["X Stacking"],
                    min = 0, max = 10, step = 1,
                },
                yStacking = {
                    order = 1,
                    type = "range",
                    name = L["Y Stacking"],
                    min = 0, max = 10, step = 1,
                },
            },
        },
        frameStrata = {
            order = 3,
            type = "group",
            inline = true,
            name = L["Frame Strata"],
            args = {
                normalFrame = {
                    order = 0,
                    type = "select",
                    name = L["Normal Frame"],
                    values = frameStratas,
                },
                targetFrame = {
                    order = 1,
                    type = "select",
                    name = L["Target Frame"],
                    values = frameStratas,
                },
            },
        },
    }
    
    ConfigPrototypes.ThreatIcon = {
        general = {
            order = 0,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                    desc = L["Enable threat icon display"],
                    width = "full",
                },
                visibility = {
                    order = 1,
                    type = "select",
                    name = L["Visibility"],
                    desc = L["When to show the threat icon"],
                    values = {
                        ["always"] = L["Always"],
                        ["combat"] = L["In Combat"],
                        ["group"] = L["In Group"],
                    },
                },
                opacity = {
                    order = 2,
                    type = "range",
                    name = L["Opacity"],
                    min = 0,
                    max = 1,
                    step = 0.01,
                },
            },
        },
        size = ConfigPrototypes:GetGeneralisedSizeConfig(),
        position = ConfigPrototypes:GetGeneralisedPositionConfig(),
    }
    
    ConfigPrototypes.CastBar = ConfigPrototypes:GetGeneralisedStatusBarConfig()
    ConfigPrototypes.CastBar.general.args.color = {
        order = 1,
        type = "color",
        name = L["Color"],
        hasAlpha = true,
    }
    ConfigPrototypes.CastBar.position = ConfigPrototypes:GetGeneralisedPositionConfig()
    
    ConfigPrototypes.SpellTimeText = ConfigPrototypes:GetGeneralisedColorFontConfig()
    ConfigPrototypes.SpellTimeText.general.args.displayType = {
        order = 1,
        type = "select",
        name = L["Display Type"],
        values = {["crtmax"] = L["Current / Max"], ["none"] = L["None"], ["crt"] = L["Current"], ["percent"] = L["Percent"], ["timeleft"] = L["Time Left"]},
    }
    
    ConfigPrototypes.SpellNameText = ConfigPrototypes:GetGeneralisedColorFontConfig()
    ConfigPrototypes.SpellNameText.general.args.maxLetters = {
        order = 5,
        type = "range",
        name = L["Max. Letters"],
        min = 1, max = 40, step = 1,
    }
    
    -- Health Bar with new coloring system
    ConfigPrototypes.HealthBar = ConfigPrototypes:GetGeneralisedStatusBarConfig()
    -- Add coloring system
    ConfigPrototypes.HealthBar.coloring = {
        order = 1.5,
        type = "group",
        inline = true,
        name = L["Coloring System"],
        args = {
            system = {
                order = 0,
                type = "select",
                name = L["Color System"],
                desc = L["Choose how nameplate colors are determined"],
                values = {
                    ["reaction"] = L["Reaction Colors (Hostile/Friendly/Neutral)"],
                    ["class"] = L["Class Colors"],
                },
                width = "full",
            },
            reactionColorsHeader = {
                order = 1,
                type = "header",
                name = L["Reaction Colors"],
                hidden = function() 
                    return NotPlater.db.profile.healthBar.coloring.system ~= "reaction" 
                end,
            },
            hostile = {
                order = 2,
                type = "color",
                name = L["Hostile"],
                desc = L["Color for hostile units"],
                hasAlpha = true,
                hidden = function() 
                    return NotPlater.db.profile.healthBar.coloring.system ~= "reaction" 
                end,
                get = function(info)
                    local color = NotPlater.db.profile.healthBar.coloring.reactionColors.hostile
                    return color.r, color.g, color.b, color.a
                end,
                set = function(info, r, g, b, a)
                    local color = NotPlater.db.profile.healthBar.coloring.reactionColors.hostile
                    color.r, color.g, color.b, color.a = r, g, b, a
                    NotPlater:Reload()
                end,
            },
            neutral = {
                order = 3,
                type = "color",
                name = L["Neutral"],
                desc = L["Color for neutral units"],
                hasAlpha = true,
                hidden = function() 
                    return NotPlater.db.profile.healthBar.coloring.system ~= "reaction" 
                end,
                get = function(info)
                    local color = NotPlater.db.profile.healthBar.coloring.reactionColors.neutral
                    return color.r, color.g, color.b, color.a
                end,
                set = function(info, r, g, b, a)
                    local color = NotPlater.db.profile.healthBar.coloring.reactionColors.neutral
                    color.r, color.g, color.b, color.a = r, g, b, a
                    NotPlater:Reload()
                end,
            },
            friendly = {
                order = 4,
                type = "color",
                name = L["Friendly"],
                desc = L["Color for friendly units"],
                hasAlpha = true,
                hidden = function() 
                    return NotPlater.db.profile.healthBar.coloring.system ~= "reaction" 
                end,
                get = function(info)
                    local color = NotPlater.db.profile.healthBar.coloring.reactionColors.friendly
                    return color.r, color.g, color.b, color.a
                end,
                set = function(info, r, g, b, a)
                    local color = NotPlater.db.profile.healthBar.coloring.reactionColors.friendly
                    color.r, color.g, color.b, color.a = r, g, b, a
                    NotPlater:Reload()
                end,
            },
            classColorsHeader = {
                order = 5,
                type = "header",
                name = L["Class Colors"],
                hidden = function() 
                    return NotPlater.db.profile.healthBar.coloring.system ~= "class" 
                end,
            },
            classColorsEnable = {
                order = 6,
                type = "toggle",
                name = L["Use Class Colors"],
                desc = L["Apply class colors to nameplates"],
                width = "full",
                hidden = function() 
                    return NotPlater.db.profile.healthBar.coloring.system ~= "class" 
                end,
                get = function(info)
                    return NotPlater.db.profile.healthBar.coloring.classColors.enable
                end,
                set = function(info, val)
                    NotPlater.db.profile.healthBar.coloring.classColors.enable = val
                    NotPlater:Reload()
                end,
            },
            playersOnly = {
                order = 7,
                type = "toggle",
                name = L["Only apply Class Colors to Players"],
                desc = L["When enabled, class colors will only be applied to player characters, not NPCs"],
                width = "full",
                hidden = function() 
                    return NotPlater.db.profile.healthBar.coloring.system ~= "class" 
                end,
                disabled = function() 
                    return not NotPlater.db.profile.healthBar.coloring.classColors.enable
                end,
                get = function(info)
                    return NotPlater.db.profile.healthBar.coloring.classColors.playersOnly
                end,
                set = function(info, val)
                    NotPlater.db.profile.healthBar.coloring.classColors.playersOnly = val
                    NotPlater:Reload()
                end,
            },
        }
    }
    
    -- Unit Filters
    ConfigPrototypes.HealthBar.unitFilters = {
        order = 1.6,
        type = "group",
        inline = true,
        name = L["Unit Filters"],
        args = {
            showPlayerTotems = {
                order = 0,
                type = "toggle",
                name = L["Show Other Player Totems"],
                desc = L["Display nameplates for other players' totems"],
                width = "full",
                get = function(info)
                    return NotPlater.db.profile.healthBar.unitFilters.showPlayerTotems
                end,
                set = function(info, val)
                    NotPlater.db.profile.healthBar.unitFilters.showPlayerTotems = val
                    NotPlater:Reload()
                end,
            },
            showOwnTotems = {
                order = 1,
                type = "toggle",
                name = L["Show Own Totems"],
                desc = L["Display nameplates for your own totems"],
                width = "full",
                get = function(info)
                    return NotPlater.db.profile.healthBar.unitFilters.showOwnTotems
                end,
                set = function(info, val)
                    NotPlater.db.profile.healthBar.unitFilters.showOwnTotems = val
                    NotPlater:Reload()
                end,
            },
            showOwnPet = {
                order = 2,
                type = "toggle",
                name = L["Show Own Pet/Minion"],
                desc = L["Display nameplates for your own pet or minion"],
                width = "full",
                get = function(info)
                    return NotPlater.db.profile.healthBar.unitFilters.showOwnPet
                end,
                set = function(info, val)
                    NotPlater.db.profile.healthBar.unitFilters.showOwnPet = val
                    NotPlater:Reload()
                end,
            },
            showOtherPlayerPets = {
                order = 3,
                type = "toggle",
                name = L["Show Other Player Pets/Minions"],
                desc = L["Display nameplates for other players' pets and minions"],
                width = "full",
                get = function(info)
                    return NotPlater.db.profile.healthBar.unitFilters.showOtherPlayerPets
                end,
                set = function(info, val)
                    NotPlater.db.profile.healthBar.unitFilters.showOtherPlayerPets = val
                    NotPlater:Reload()
                end,
            },
        }
    }
    
    ConfigPrototypes.HealthText = ConfigPrototypes:GetGeneralisedColorFontConfig()
    ConfigPrototypes.HealthText.general.args.displayType = {
        order = 1,
        type = "select",
        name = L["Display Type"],
        values = {["none"] = L["None"], ["minmax"] = L["Min / Max"], ["both"] = L["Both"], ["percent"] = L["Percent"]},
    }
    ConfigPrototypes.NameText = ConfigPrototypes:GetGeneralisedFontConfig()
    ConfigPrototypes.LevelText = ConfigPrototypes:GetGeneralisedFontConfig()
    ConfigPrototypes.LevelText.general.args.opacity = {
        order = 1,
        type = "range",
        name = L["Opacity"],
        min = 0, max = 1, step = 0.01,
    }
    ConfigPrototypes.Icon = ConfigPrototypes:GetGeneralisedIconConfig()
    ConfigPrototypes.CastBarIcon = ConfigPrototypes:GetGeneralisedIconConfig()
    ConfigPrototypes.CastBarIcon.border = ConfigPrototypes:GetGeneralisedBorderConfig()
    ConfigPrototypes.CastBarIcon.background = ConfigPrototypes:GetGeneralisedBackgroundConfig()
    ConfigPrototypes.Target = {
        scale = {
            order = 0,
            type = "group",
            name = L["Scale"],
            inline = true,
            args = {
                scalingFactor = {
                    order = 0,
                    type = "range",
                    width = "full",
                    name = L["Scaling Factor"],
                    min = 1, max = 2, step = 0.01,
                },
                healthBar = {
                    order = 2,
                    type = "toggle",
                    name = L["Health Bar"],
                },
                castBar = {
                    order = 3,
                    type = "toggle",
                    name = L["Cast Bar"],
                },
                nameText = {
                    order = 4,
                    type = "toggle",
                    name = L["Name Text"],
                },
                levelText = {
                    order = 5,
                    type = "toggle",
                    name = L["Level Text"],
                },
                raidIcon = {
                    order = 6,
                    type = "toggle",
                    name = L["Raid Icon"],
                },
                bossIcon = {
                    order = 7,
                    type = "toggle",
                    name = L["Boss Icon"],
                },
                targetTargetText = {
                    order = 8,
                    type = "toggle",
                    name = L["Target-Target Text"],
                },
                threatIcon = {
                    order = 9,
                    type = "toggle",
                    name = L["Threat Icon"],
                },
            },
        },
        border = {
            order = 1,
            type = "group",
            name = L["Border"],
            inline = true,
            args = {
                indicator = {
                    order = 0,
                    type = "group",
                    name = L["Indicator"],
                    args = {
                        enable = {
                            order = 0,
                            type = "toggle",
                            name = L["Enable"],
                        },
                        selection = {
                            order = 1,
                            type = "select",
                            name = L["Selection"],
                            values = GetIndicators,
                        },
                    },
                },
                highlight = {
                    order = 1,
                    type = "group",
                    name = L["Highlight"],
                    args = {
                        enable = {
                            order = 0,
                            type = "toggle",
                            name = L["Enable"],
                        },
                        color = {
                            order = 1,
                            type = "color",
                            name = L["Color"],
                            hasAlpha = true,
                        },
                        texture = {
                            order = 2,
                            type = "select",
                            name = L["Texture"],
                            values = NotPlater.targetHighlights,
                        },
                        thickness = {
                            order = 3,
                            type = "range",
                            name = L["Thickness"],
                            min = 1, max = 30, step = 1,
                        },
                    },
                },
            },
        },
        overlay = {
            order = 2,
            type = "group",
            name = L["Overlay"],
            inline = true,
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                },
                color = {
                    order = 1,
                    type = "color",
                    name = L["Color"],
                    hasAlpha = true,
                },
                texture = {
                    order = 2,
                    type = "select",
                    name = L["Texture"],
                    values = GetTextures,
                },
            },
        },
        nonTargetAlpha = {
            order = 3,
            type = "group",
            name = L["Non-Target Alpha"],
            inline = true,
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                },
                opacity = {
                    order = 1,
                    type = "range",
                    name = L["Opacity"],
                    min = 0, max = 0.98, step = 0.01,
                },
            },
        },
        nonTargetShading = {
            order = 4,
            type = "group",
            name = L["Non-Target Shading"],
            inline = true,
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                },
                opacity = {
                    order = 1,
                    type = "range",
                    name = L["Opacity"],
                    min = 0, max = 1, step = 0.01,
                },
            },
        },
        mouseoverHighlight = {
            order = 5,
            type = "group",
            name = L["Mouseover Highlight"],
            inline = true,
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable"],
                },
                opacity = {
                    order = 1,
                    type = "range",
                    name = L["Opacity"],
                    min = 0, max = 1, step = 0.01,
                },
            },
        },
    }
    ConfigPrototypes.TargetTargetText = ConfigPrototypes:GetGeneralisedColorFontConfig()
    ConfigPrototypes.TargetTargetText.general.args.maxLetters = {
        order = 5,
        type = "range",
        name = L["Max. Letters"],
        min = 1, max = 40, step = 1,
    }
    ConfigPrototypes.Simulator = {
        general = {
            order = 1,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                showOnConfig = {
                    order = 0,
                    type = "toggle",
                    width = "double",
                    name = L["Show simulator when showing config"],
                },
                execSim = {
                    order = 1,
                    type = "execute",
                    name = L["Toggle Simulator Frame"],
                    func = function () NotPlater:ToggleSimulatorFrame() end,
                },
            },
        },
        size = ConfigPrototypes:GetGeneralisedSizeConfig()
    }
    ConfigPrototypes.GuildCache = {
        general = {
            order = 0,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable Guild Cache"],
                    desc = L["Enable guild member caching and class color enhancement"],
                    width = "full",
                    set = function(info, val)
                        NotPlater.db.profile.guildCache.general.enable = val
                        if val and NotPlater.GuildCache then
                            -- Re-initialize if enabled
                            NotPlater.GuildCache:Initialize()
                        elseif not val and NotPlater.GuildCache then
                            -- Clear cache if disabled
                            NotPlater.GuildCache:ClearCache()
                        end
                        NotPlater:Reload()
                    end,
                    get = function(info)
                        return NotPlater.db.profile.guildCache.general.enable
                    end,
                },
                useGuildClassColors = {
                    order = 1,
                    type = "toggle",
                    name = L["Use Guild Class Colors"],
                    desc = L["Apply class colors to guild member nameplates immediately"],
                    width = "full",
                    disabled = function() 
                        return not NotPlater.db.profile.guildCache.general.enable 
                    end,
                },
                showCacheMessages = {
                    order = 2,
                    type = "toggle",
                    name = L["Show Cache Messages"],
                    desc = L["Display chat messages when guild roster is updated"],
                    disabled = function() 
                        return not NotPlater.db.profile.guildCache.general.enable 
                    end,
                },
            },
        },
        statistics = {
            order = 1,
            type = "group",
            inline = true,
            name = L["Statistics"],
            args = {
                header = {
                    order = 0,
                    type = "header",
                    name = L["Guild Cache Information"],
                },
                memberCount = {
                    order = 1,
                    type = "description",
                    name = function()
                        if NotPlater.GuildCache then
                            local count = 0
                            if type(NotPlater.GuildCache.GetMemberCount) == "function" then
                                count = NotPlater.GuildCache:GetMemberCount()
                            end
                            return string.format(L["Cached Members: %d"], count)
                        else
                            return L["Guild cache not initialized"]
                        end
                    end,
                    fontSize = "medium",
                },
                guildStatus = {
                    order = 2,
                    type = "description",
                    name = function()
                        local inGuild = IsInGuild()
                        if inGuild then
                            local guildName = GetGuildInfo("player")
                            return string.format(L["Guild: %s"], guildName or L["Unknown"])
                        else
                            return L["Not in a guild"]
                        end
                    end,
                    fontSize = "medium",
                },
                lastUpdate = {
                    order = 3,
                    type = "description",
                    name = function()
                        if NotPlater.GuildCache and NotPlater.GuildCache.IsRefreshInProgress and NotPlater.GuildCache:IsRefreshInProgress() then
                            return "|cffFFFF00Refresh in progress...|r"
                        elseif NotPlater.GuildCache and NotPlater.GuildCache.GetLastUpdateTime then
                            local lastTime = NotPlater.GuildCache:GetLastUpdateTime()
                            if lastTime then
                                return string.format(L["Last Update: %s"], date("%H:%M:%S", lastTime))
                            else
                                return L["Never updated"]
                            end
                        else
                            return L["Update info not available"]
                        end
                    end,
                    fontSize = "medium",
                },
                spacer1 = {
                    order = 4,
                    type = "description",
                    name = " ",
                },
                memberListHeader = {
                    order = 5,
                    type = "header",
                    name = L["Cached Guild Members"],
                },
                memberList = {
                    order = 6,
                    type = "description",
                    name = function()
                        if not NotPlater.GuildCache or not NotPlater.GuildCache.GetMemberList then
                            return L["Guild cache not available"]
                        end
                        
                        local members = NotPlater.GuildCache:GetMemberList()
                        if not members or #members == 0 then
                            return L["No guild members cached"]
                        end
                        
                        -- Sort members by name
                        table.sort(members, function(a, b) return a.name < b.name end)
                        
                        local lines = {}
                        for i, member in ipairs(members) do
                            local classColor = member.classColor
                            local colorCode = ""
                            if classColor then
                                -- Convert RGB to hex color code
                                local r = math.floor(classColor.r * 255)
                                local g = math.floor(classColor.g * 255)
                                local b = math.floor(classColor.b * 255)
                                colorCode = string.format("|cff%02x%02x%02x", r, g, b)
                            end
                            
                            local line = string.format("%s%s|r - Level %d %s%s|r (%s)", 
                                colorCode, 
                                member.name, 
                                member.level or 0,
                                colorCode,
                                member.class or "Unknown",
                                member.online and "Online" or "Offline"
                            )
                            table.insert(lines, line)
                            
                            -- Limit to first 50 members to prevent UI overflow
                            if i >= 50 then
                                table.insert(lines, string.format("... and %d more members", #members - 50))
                                break
                            end
                        end
                        
                        return table.concat(lines, "\n")
                    end,
                    fontSize = "small",
                    width = "full",
                },
                spacer2 = {
                    order = 7,
                    type = "description",
                    name = " ",
                },
                refreshButton = {
                    order = 8,
                    type = "execute",
                    name = L["Refresh Guild Cache"],
                    desc = L["Manually refresh the guild roster cache"],
                    func = function()
                        if NotPlater.GuildCache and NotPlater.GuildCache.RequestGuildRoster then
                            local oldCount = 0
                            if NotPlater.GuildCache.GetMemberCount then
                                oldCount = NotPlater.GuildCache:GetMemberCount()
                            end
                            
                            NotPlater.GuildCache:RequestGuildRoster()
                            
                            -- Show immediate feedback with safe string handling
                            local message = "Guild roster refresh requested"
                            if oldCount and oldCount > 0 then
                                message = message .. " (currently " .. tostring(oldCount) .. " cached)"
                            end
                            
                            -- Use direct chat output instead of NotPlater:Print
                            if DEFAULT_CHAT_FRAME then
                                DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: " .. message)
                            end
                            
                            -- Force immediate interface refresh
                            if NotPlater.GuildCache.RefreshConfigInterface then
                                NotPlater.GuildCache:RefreshConfigInterface()
                            end
                        end
                    end,
                    disabled = function() 
                        return not NotPlater.db.profile.guildCache.general.enable or not IsInGuild()
                    end,
                },
            },
        },
        advanced = {
            order = 2,
            type = "group",
            inline = true,
            name = L["Advanced"],
            args = {
                updateThrottle = {
                    order = 0,
                    type = "range",
                    name = L["Update Throttle"],
                    desc = L["Minimum seconds between guild roster requests"],
                    min = 1,
                    max = 10,
                    step = 1,
                    get = function(info) return NotPlater.db.profile.guildCache.advanced.updateThrottle end,
                    set = function(info, val) 
                        NotPlater.db.profile.guildCache.advanced.updateThrottle = val
                        NotPlater:Reload()
                    end,
                    disabled = function() 
                        return not NotPlater.db.profile.guildCache.general.enable 
                    end,
                },
                debugMode = {
                    order = 1,
                    type = "toggle",
                    name = L["Debug Mode"],
                    desc = L["Enable debug messages for guild cache operations"],
                    get = function(info) return NotPlater.db.profile.guildCache.advanced.debugMode end,
                    set = function(info, val) NotPlater.db.profile.guildCache.advanced.debugMode = val end,
                    disabled = function() 
                        return not NotPlater.db.profile.guildCache.general.enable 
                    end,
                },
            },
        },
    }
    ConfigPrototypes.PartyRaidCache = {
        general = {
            order = 0,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable Party/Raid Cache"],
                    desc = L["Enable party and raid member caching for class colors"],
                    width = "full",
                    set = function(info, val)
                        NotPlater.db.profile.partyRaidCache.general.enable = val
                        if val and NotPlater.PartyRaidCache then
                            NotPlater.PartyRaidCache:Initialize()
                        elseif not val and NotPlater.PartyRaidCache then
                            NotPlater.PartyRaidCache:ClearCache()
                        end
                        NotPlater:Reload()
                    end,
                    get = function(info)
                        return NotPlater.db.profile.partyRaidCache.general.enable
                    end,
                },
                usePartyRaidColors = {
                    order = 1,
                    type = "toggle",
                    name = L["Use Party/Raid Class Colors"],
                    desc = L["Apply class colors to party and raid member nameplates"],
                    width = "full",
                    disabled = function() 
                        return not NotPlater.db.profile.partyRaidCache.general.enable 
                    end,
                },
                showCacheMessages = {
                    order = 2,
                    type = "toggle",
                    name = L["Show Cache Messages"],
                    desc = L["Display chat messages when party/raid roster is updated"],
                    disabled = function() 
                        return not NotPlater.db.profile.partyRaidCache.general.enable 
                    end,
                },
            },
        },
        statistics = {
            order = 1,
            type = "group",
            inline = true,
            name = L["Statistics"],
            args = {
                header = {
                    order = 0,
                    type = "header",
                    name = L["Party/Raid Cache Information"],
                },
                memberCount = {
                    order = 1,
                    type = "description",
                    name = function()
                        if NotPlater.PartyRaidCache then
                            local count = NotPlater.PartyRaidCache:GetMemberCount()
                            return string.format(L["Cached Members: %d"], count)
                        else
                            return L["Party/Raid cache not initialized"]
                        end
                    end,
                    fontSize = "medium",
                },
                groupStatus = {
                    order = 2,
                    type = "description",
                    name = function()
                        if NotPlater.PartyRaidCache then
                            local groupType = NotPlater.PartyRaidCache:GetGroupType()
                            if groupType == "raid" then
                                return L["Currently in a Raid"]
                            elseif groupType == "party" then
                                return L["Currently in a Party"]
                            else
                                return L["Not in a group"]
                            end
                        else
                            return L["Not in a group"]
                        end
                    end,
                    fontSize = "medium",
                },
                lastUpdate = {
                    order = 3,
                    type = "description",
                    name = function()
                        if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.GetLastUpdateTime then
                            local lastTime = NotPlater.PartyRaidCache:GetLastUpdateTime()
                            if lastTime then
                                return string.format(L["Last Update: %s"], date("%H:%M:%S", lastTime))
                            else
                                return L["Never updated"]
                            end
                        else
                            return L["Update info not available"]
                        end
                    end,
                    fontSize = "medium",
                },
                spacer1 = {
                    order = 4,
                    type = "description",
                    name = " ",
                },
                memberListHeader = {
                    order = 5,
                    type = "header",
                    name = L["Cached Group Members"],
                },
                memberList = {
                    order = 6,
                    type = "description",
                    name = function()
                        if not NotPlater.PartyRaidCache or not NotPlater.PartyRaidCache.GetMemberList then
                            return L["Party/Raid cache not available"]
                        end
                        
                        local members = NotPlater.PartyRaidCache:GetMemberList()
                        if not members or #members == 0 then
                            return L["No group members cached"]
                        end
                        
                        -- Sort members by name
                        table.sort(members, function(a, b) return a.name < b.name end)
                        
                        local lines = {}
                        for i, member in ipairs(members) do
                            local classColor = member.classColor
                            local colorCode = ""
                            if classColor then
                                local r = math.floor(classColor.r * 255)
                                local g = math.floor(classColor.g * 255)
                                local b = math.floor(classColor.b * 255)
                                colorCode = string.format("|cff%02x%02x%02x", r, g, b)
                            end
                            
                            local line = string.format("%s%s|r - Level %d %s%s|r (%s)", 
                                colorCode, 
                                member.name, 
                                member.level or 0,
                                colorCode,
                                member.class or "Unknown",
                                member.online and "Online" or "Offline"
                            )
                            
                            -- Add role/subgroup info for raids
                            if member.subgroup then
                                line = line .. " [Group " .. member.subgroup .. "]"
                            end
                            
                            table.insert(lines, line)
                        end
                        
                        return table.concat(lines, "\n")
                    end,
                    fontSize = "small",
                    width = "full",
                },
                spacer2 = {
                    order = 7,
                    type = "description",
                    name = " ",
                },
                refreshButton = {
                    order = 8,
                    type = "execute",
                    name = L["Refresh Party/Raid Cache"],
                    desc = L["Manually refresh the party/raid roster cache"],
                    func = function()
                        if NotPlater.PartyRaidCache and NotPlater.PartyRaidCache.UpdateRoster then
                            NotPlater.PartyRaidCache:UpdateRoster()
                            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Party/Raid roster refreshed")
                        end
                    end,
                    disabled = function() 
                        return not NotPlater.db.profile.partyRaidCache.general.enable or 
                               (not UnitInParty("player") and not UnitInRaid("player"))
                    end,
                },
            },
        },
        advanced = {
            order = 2,
            type = "group",
            inline = true,
            name = L["Advanced"],
            args = {
                debugMode = {
                    order = 0,
                    type = "toggle",
                    name = L["Debug Mode"],
                    desc = L["Enable debug messages for party/raid cache operations"],
                    get = function(info) return NotPlater.db.profile.partyRaidCache.advanced.debugMode end,
                    set = function(info, val) NotPlater.db.profile.partyRaidCache.advanced.debugMode = val end,
                    disabled = function() 
                        return not NotPlater.db.profile.partyRaidCache.general.enable 
                    end,
                },
            },
        },
    }
    ConfigPrototypes.RecentlySeenCache = {
        general = {
            order = 0,
            type = "group",
            inline = true,
            name = L["General"],
            args = {
                enable = {
                    order = 0,
                    type = "toggle",
                    name = L["Enable Recently Seen Cache"],
                    desc = L["Cache players you've seen recently for faster class color detection"],
                    width = "full",
                    set = function(info, val)
                        NotPlater.db.profile.recentlySeenCache.general.enable = val
                        NotPlater:Reload()
                    end,
                    get = function(info)
                        return NotPlater.db.profile.recentlySeenCache.general.enable
                    end,
                },
                useRecentlySeenColors = {
                    order = 1,
                    type = "toggle",
                    name = L["Use Recently Seen Class Colors"],
                    desc = L["Apply class colors to recently seen players"],
                    width = "full",
                    disabled = function() 
                        return not NotPlater.db.profile.recentlySeenCache.general.enable 
                    end,
                },
                pruneDays = {
                    order = 2,
                    type = "select",
                    name = L["Keep Players For"],
                    desc = L["How many days to keep players in the cache"],
                    values = {
                        [3] = L["3 days"],
                        [5] = L["5 days"],
                        [7] = L["7 days"],
                        [9] = L["9 days"],
                    },
                    disabled = function() 
                        return not NotPlater.db.profile.recentlySeenCache.general.enable 
                    end,
                },
                maxEntries = {
                    order = 3,
                    type = "range",
                    name = L["Maximum Cache Size"],
                    desc = L["Maximum number of players to keep in cache"],
                    min = 100,
                    max = 1000,
                    step = 50,
                    disabled = function() 
                        return not NotPlater.db.profile.recentlySeenCache.general.enable 
                    end,
                },
                showCacheMessages = {
                    order = 4,
                    type = "toggle",
                    name = L["Show Cache Messages"],
                    desc = L["Display messages when the cache is updated"],
                    disabled = function() 
                        return not NotPlater.db.profile.recentlySeenCache.general.enable 
                    end,
                },
            },
        },
        statistics = {
            order = 1,
            type = "group",
            inline = true,
            name = L["Statistics"],
            args = {
                header = {
                    order = 0,
                    type = "header",
                    name = L["Recently Seen Cache Information"],
                },
                cacheSize = {
                    order = 1,
                    type = "description",
                    name = function()
                        if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.GetStatistics then
                            local stats = NotPlater.RecentlySeenCache:GetStatistics()
                            return string.format(L["Cached Players: %d"], stats.size)
                        else
                            return L["Recently Seen cache not initialized"]
                        end
                    end,
                    fontSize = "medium",
                },
                hitRate = {
                    order = 2,
                    type = "description",
                    name = function()
                        if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.GetStatistics then
                            local stats = NotPlater.RecentlySeenCache:GetStatistics()
                            return string.format(L["Cache Hit Rate: %.1f%%"], stats.hitRate)
                        else
                            return L["No statistics available"]
                        end
                    end,
                    fontSize = "medium",
                },
                statistics = {
                    order = 3,
                    type = "description",
                    name = function()
                        if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.GetStatistics then
                            local stats = NotPlater.RecentlySeenCache:GetStatistics()
                            return string.format(L["Hits: %d | Misses: %d | Added: %d | Pruned: %d"], 
                                stats.hits, stats.misses, stats.added, stats.pruned)
                        else
                            return ""
                        end
                    end,
                    fontSize = "small",
                },
                spacer1 = {
                    order = 4,
                    type = "description",
                    name = " ",
                },
                recentPlayersHeader = {
                    order = 5,
                    type = "header",
                    name = L["Recently Seen Players"],
                },
                recentPlayers = {
                    order = 6,
                    type = "description",
                    name = function()
                        if not NotPlater.RecentlySeenCache or not NotPlater.RecentlySeenCache.GetCacheList then
                            return L["Recently Seen cache not available"]
                        end
                        
                        local players = NotPlater.RecentlySeenCache:GetCacheList()
                        if not players or #players == 0 then
                            return L["No recently seen players cached"]
                        end
                        
                        local lines = {}
                        local currentTime = GetTime()
                        for i, player in ipairs(players) do
                            local classColor = player.classColor
                            local colorCode = ""
                            if classColor then
                                local r = math.floor(classColor.r * 255)
                                local g = math.floor(classColor.g * 255)
                                local b = math.floor(classColor.b * 255)
                                colorCode = string.format("|cff%02x%02x%02x", r, g, b)
                            end
                            
                            -- Calculate time ago
                            local timeAgo = currentTime - player.lastSeen
                            local timeString = ""
                            if timeAgo < 60 then
                                timeString = "< 1 min ago"
                            elseif timeAgo < 3600 then
                                timeString = string.format("%d min ago", math.floor(timeAgo / 60))
                            elseif timeAgo < 86400 then
                                timeString = string.format("%.1f hours ago", timeAgo / 3600)
                            else
                                timeString = string.format("%.1f days ago", timeAgo / 86400)
                            end
                            
                            local line = string.format("%s%s|r - Level %d %s%s|r (%s)", 
                                colorCode, 
                                player.name, 
                                player.level or 0,
                                colorCode,
                                player.class or "Unknown",
                                timeString
                            )
                            table.insert(lines, line)
                            
                            -- Limit to first 30 players
                            if i >= 30 then
                                table.insert(lines, string.format("... and %d more players", #players - 30))
                                break
                            end
                        end
                        
                        return table.concat(lines, "\n")
                    end,
                    fontSize = "small",
                    width = "full",
                },
                spacer2 = {
                    order = 7,
                    type = "description",
                    name = " ",
                },
                clearButton = {
                    order = 8,
                    type = "execute",
                    name = L["Clear Recently Seen Cache"],
                    desc = L["Clear all recently seen players from cache"],
                    func = function()
                        if NotPlater.RecentlySeenCache and NotPlater.RecentlySeenCache.ClearCache then
                            NotPlater.RecentlySeenCache:ClearCache()
                            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NotPlater|r: Recently seen cache cleared")
                        end
                    end,
                    confirm = true,
                    confirmText = L["Are you sure you want to clear the recently seen cache?"],
                    disabled = function() 
                        return not NotPlater.db.profile.recentlySeenCache.general.enable
                    end,
                },
            },
        },
        advanced = {
            order = 2,
            type = "group",
            inline = true,
            name = L["Advanced"],
            args = {
                debugMode = {
                    order = 0,
                    type = "toggle",
                    name = L["Debug Mode"],
                    desc = L["Enable debug messages for recently seen cache operations"],
                    get = function(info) return NotPlater.db.profile.recentlySeenCache.advanced.debugMode end,
                    set = function(info, val) NotPlater.db.profile.recentlySeenCache.advanced.debugMode = val end,
                    disabled = function() 
                        return not NotPlater.db.profile.recentlySeenCache.general.enable 
                    end,
                },
            },
        },
    }
end